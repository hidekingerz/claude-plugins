#!/usr/bin/env bash
#
# run-in-docker.sh — single-agent-loop を隔離コンテナで回すラッパー
#
# リポジトリ「だけ」を /workspace にマウントし、ホームの機密（~/.ssh, ~/.aws 等）は渡さず、
# 使い捨てコンテナ内で loop/run.sh を実行する。破壊的操作とプロンプトインジェクションの影響を
# コンテナ内に閉じ込めるのが目的（git ブランチはホストを守らない。詳細は gate-design.md「8.」）。
#
# ★残留物に注意: リポジトリは rw マウントのため、コンテナ内での変更はホストに残る。特に
#   .git/hooks・.git/config・loop/*.sh への改変は「次にホストで git やループを実行した時」に
#   ホスト側でコードが走る持続化ベクタになる。本スクリプトは実行前後でこれらのハッシュを比較し、
#   変化があれば警告する（検知であって防止ではない。警告が出たら差分を確認してから git を叩く）。
#
# 使い方:
#   export ANTHROPIC_API_KEY=sk-ant-...              # 認証その1: API 課金（Console のキー）
#   export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat...     # 認証その2: Pro/Max サブスク（`claude setup-token`）
#   VERIFY_CMD="<品質ゲート>" ./loop/run-in-docker.sh # ↑どちらか一方があればよい
#
# 上書き可能な環境変数:
#   LOOP_IMAGE          ビルドするイメージ名（既定: single-agent-loop:latest）
#   LOOP_DOCKERFILE     使う Dockerfile（既定: Dockerfile。フロント+MCP 検証なら Dockerfile.frontend）
#   LOOP_NETWORK        docker network（既定: bridge）。API/レジストリに届く必要があるため完全遮断は
#                       不可。宛先を絞るなら egress proxy 等を別途用意し、その network 名をここに指定。
#   HOST_BACKEND        "1" で --add-host host.docker.internal:host-gateway を付与し、E2E 等で
#                       ホスト常駐バックエンドへ http://host.docker.internal:<PORT> で到達できるようにする
#                       （既定: 無効。必要な実行だけで有効化する。macOS の Docker Desktop は元々
#                       host.docker.internal が引けるため、これは主に Linux 向け）。
#   LOOP_DOCKER_FLAGS   docker run へ追加で渡すフラグ（例: Linux で所有権を保つ '--user 1000:1000'）
#   VERIFY_CMD / MAX_ITER / MAX_CONSEC_FAIL / MAX_CONSEC_VERIFY_FAIL / AGENT_CMD / DONE_MARKER
#                       … loop/run.sh へそのまま引き継がれる（未設定なら run.sh の既定値）。

set -euo pipefail

# リポジトリルートへ（このスクリプトは loop/ 配下にある想定）
cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"

IMAGE="${LOOP_IMAGE:-single-agent-loop:latest}"

# 認証（無人ループのため対話ログインは使えない）。どちらか一方を渡す:
#   ANTHROPIC_API_KEY        … API 課金（Console のキー）
#   CLAUDE_CODE_OAUTH_TOKEN  … Pro/Max サブスク（`claude setup-token` で発行した長期トークン）
if [[ -z "${ANTHROPIC_API_KEY:-}" && -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  echo "ERROR: ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN のどちらも未設定です（コンテナ内 claude -p の認証に必須）。" >&2
  exit 1
fi

DOCKERFILE="${LOOP_DOCKERFILE:-Dockerfile}"
if [[ ! -f "loop/$DOCKERFILE" ]]; then
  echo "ERROR: loop/$DOCKERFILE が見つかりません（cwd=$PWD）。assets/$DOCKERFILE を loop/ に配置してください。" >&2
  exit 1
fi

# Dockerfile.frontend（ブラウザ/MCP 検証）に必須のフラグを自動付与する（ユーザーに手渡しさせない＝
# compose 経路との非対称・付け忘れを防ぐ）。既に LOOP_DOCKER_FLAGS で指定済みなら重複させない:
#   ・-v /workspace/node_modules … host（macOS/arm64）の node_modules を隔離（native バイナリ衝突回避）。
#     ★これは frontend の時だけ。既定 Dockerfile では隔離しない（pure-JS の bind mount を壊さないため）。
#   ・--security-opt seccomp=loop/chromium-seccomp.json … Docker 既定 seccomp が unprivileged userns を
#     塞ぎ chromium sandbox が起動できないのを解消（chrome-devtools MCP 用）。
LOOP_DOCKER_FLAGS="${LOOP_DOCKER_FLAGS:-}"
if [[ "$DOCKERFILE" == "Dockerfile.frontend" ]]; then
  [[ "$LOOP_DOCKER_FLAGS" == *"/workspace/node_modules"* ]] || LOOP_DOCKER_FLAGS="$LOOP_DOCKER_FLAGS -v /workspace/node_modules"
  if [[ "$LOOP_DOCKER_FLAGS" != *"seccomp="* ]]; then
    if [[ -f loop/chromium-seccomp.json ]]; then
      LOOP_DOCKER_FLAGS="$LOOP_DOCKER_FLAGS --security-opt seccomp=loop/chromium-seccomp.json"
    else
      echo "WARNING: loop/chromium-seccomp.json が無いため seccomp プロファイルを付与できません（chrome-devtools MCP の sandbox が起動しない可能性）。assets/chromium-seccomp.json を loop/ に配置してください。" >&2
    fi
  fi
fi

# コンテナ内 git commit 用の identity（ホストの設定を引き継ぐ）
GIT_NAME="$(git config user.name 2>/dev/null || echo loop-agent)"
GIT_EMAIL="$(git config user.email 2>/dev/null || echo loop@example.invalid)"

# --- ホスト持続化ベクタの整合性スナップショット --------------------------------------------
# コンテナが書き換えると「後でホスト側で実行される」ファイル群（git hooks / git config /
# ループスクリプト自身）のハッシュを実行前後で比較する。
hash_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}
integrity_snapshot() {
  {
    [[ -f .git/config ]] && echo .git/config
    [[ -d .git/hooks ]] && find .git/hooks -type f
    find loop -maxdepth 1 -type f \( -name '*.sh' -o -name 'Dockerfile*' -o -name 'docker-compose.yml' \) 2>/dev/null
  } | LC_ALL=C sort | while IFS= read -r f; do hash_cmd "$f"; done
}
pre_snapshot="$(integrity_snapshot)"
# --------------------------------------------------------------------------------------------

echo "== build image: $IMAGE (dockerfile: $DOCKERFILE) =="
docker build -t "$IMAGE" -f "loop/$DOCKERFILE" loop/

# 注: docker run は下で**背景実行 + wait**する（シグナル即応のため）。背景プロセスに `-t`
# （pty 割当）を付けると、フォアグラウンドでない TTY 制御で端末が壊れる/出力が乱れることがあるため、
# pty は割り当てない（ログはそのまま stdout に流れる）。

# ホスト常駐バックエンドへの経路は必要な実行でだけ開ける（HOST_BACKEND=1）
host_flag=()
if [[ "${HOST_BACKEND:-0}" == "1" ]]; then
  host_flag=(--add-host host.docker.internal:host-gateway)
  echo "NOTE: HOST_BACKEND=1 — コンテナから host.docker.internal でホストへ到達できます（E2E 用）。"
fi

# コンテナに名前を付け、ラッパー（この docker run）が停止したら確実にコンテナも止める。
# 背景: ラッパーが SIGINT/SIGTERM やハーネスの実行時間上限で殺されても、コンテナは detach した
#       まま iteration を回し続け、監視外で commit を継続してしまうことがある（特に Docker
#       Desktop）。名前を付けておけば `docker ps`/`docker stop` で確実に特定・停止でき、下の
#       trap で INT/TERM・正常終了時には自動停止する。
# 注意: SIGKILL(kill -9) は trap できないため自動停止しない。その場合は下記の名前で
#       `docker stop single-agent-loop-run-<pid>` を手動実行するか、`docker ps` で拾って止める。
CONTAINER_NAME="single-agent-loop-run-$$"
cleanup_container() { docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true; }
# INT/TERM を受けたら即コンテナを停止する。★docker run を前景で実行すると、bash はその子プロセスの
# 終了を待つ間シグナルの trap を遅延させるため、ラッパーだけに SIGTERM が来てもコンテナが止まらない
# （孤立コンテナが回り続ける）。そこで docker run を背景実行し `wait` で待つ: `wait` はシグナルで
# 即中断されるので、trap が直ちに走ってコンテナを停止できる。
docker_pid=""
on_signal() {
  echo >&2; echo "== signal received — stopping container $CONTAINER_NAME ==" >&2
  # まだコンテナ生成前にシグナルが来たケース: docker CLI 自体を止めて生成を防ぐ。
  [[ -n "$docker_pid" ]] && kill "$docker_pid" 2>/dev/null || true
  cleanup_container
  # CLI が停止直前にコンテナを作り始めた取りこぼしに備え、一度だけリトライ（残存レースの縮小）。
  sleep 1; cleanup_container
}
trap on_signal INT TERM
trap cleanup_container EXIT

echo "== run loop in container (name=$CONTAINER_NAME, network=${LOOP_NETWORK:-bridge}) =="
rc=0
# shellcheck disable=SC2086
docker run --rm --name "$CONTAINER_NAME" \
  --network "${LOOP_NETWORK:-bridge}" \
  ${host_flag[@]+"${host_flag[@]}"} \
  -v "$REPO_ROOT":/workspace \
  -w /workspace \
  -e ANTHROPIC_API_KEY \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e IS_SANDBOX=1 \
  -e VERIFY_CMD \
  -e MAX_ITER \
  -e MAX_CONSEC_FAIL \
  -e MAX_CONSEC_VERIFY_FAIL \
  -e AGENT_CMD \
  -e DONE_MARKER \
  -e GIT_AUTHOR_NAME="$GIT_NAME" -e GIT_COMMITTER_NAME="$GIT_NAME" \
  -e GIT_AUTHOR_EMAIL="$GIT_EMAIL" -e GIT_COMMITTER_EMAIL="$GIT_EMAIL" \
  ${LOOP_DOCKER_FLAGS:-} \
  "$IMAGE" \
  ./loop/run.sh &
docker_pid=$!
# wait はシグナル受信で即座に戻る（trap 実行後）。シグナル無しなら docker run の終了コードを得る。
wait "$docker_pid" || rc=$?

# --- 実行後の整合性チェック（失敗時も必ず実施） ---------------------------------------------
post_snapshot="$(integrity_snapshot)"
if [[ "$pre_snapshot" != "$post_snapshot" ]]; then
  echo
  echo "!!==========================================================================!!" >&2
  echo "!! WARNING: ループ実行中に .git/hooks・.git/config・loop/ のスクリプトが      " >&2
  echo "!! 変更されました。これらは次にホストで git / ループを実行した時にホスト側で  " >&2
  echo "!! コードが走りうるファイルです。差分を確認するまで git 操作をしないこと。    " >&2
  echo "!!==========================================================================!!" >&2
  echo "-- 変更されたファイル:" >&2
  # diff は差分ありで exit 1 を返すため、pipefail でスクリプトが死なないよう || true を付ける
  diff <(echo "$pre_snapshot") <(echo "$post_snapshot") | sed -n 's/^[<>] //p' | awk '{print $2}' | sort -u >&2 || true
  if [[ $rc -eq 0 ]]; then rc=4; fi
fi
# --------------------------------------------------------------------------------------------

exit "$rc"
