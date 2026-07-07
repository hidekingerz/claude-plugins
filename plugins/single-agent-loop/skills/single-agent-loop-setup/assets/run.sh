#!/usr/bin/env bash
#
# run.sh — Closed Single-Agent Loop runner（ハードニング済み・汎用テンプレート）
#
# エージェントに loop/LOOP_PROMPT.md を毎周フレッシュなコンテキストで渡し、出力に停止サイン
# （LOOP_DONE）が出るか最大反復回数に達するまで繰り返す。記憶は loop/MEMORY.md とリポ状態が担う。
# 作業ディレクトリはリポジトリルート（このスクリプトの親ディレクトリ）。
#
# 使い方:
#   chmod +x loop/run.sh
#   VERIFY_CMD="<品質ゲート>" ./loop/run.sh
#
# 環境変数（必要に応じて上書き）:
#   AGENT_CMD       エージェント1回実行コマンド。プロンプトを stdin で受け、標準出力に返す。
#                   既定: `claude -p --dangerously-skip-permissions -`
#                   （無人ループのため権限確認をバイパス。feature ブランチ + RULES + VERIFY が安全網）
#   PROMPT_FILE     ループ用プロンプト（既定: loop/LOOP_PROMPT.md）
#   MAX_ITER        最大反復回数（トークン暴走防止。既定: 8。長丁場は再実行前提）
#   DONE_MARKER     停止サイン（既定: LOOP_DONE）
#   VERIFY_CMD      各周のエージェント実行後に走らせる品質ゲート（closed loop の二重安全網）。
#                   ★必ず設定すること。ここが空だとループは「壊れていても緑」を出荷しうる。
#                   例: "cd app && npm test && npm run lint && npm run typecheck"
#   MAX_CONSEC_FAIL 連続失敗で停止する閾値（既定: 3。API/セッション制限・障害での空回り防止）
#   MAX_CONSEC_VERIFY_FAIL  VERIFY が連続で失敗したら停止する閾値（既定: 5。ゲートに詰まった
#                   ループが MAX_ITER まで暴走するのを防ぐ）

set -euo pipefail

AGENT_CMD="${AGENT_CMD:-claude -p --dangerously-skip-permissions -}"
PROMPT_FILE="${PROMPT_FILE:-loop/LOOP_PROMPT.md}"
MAX_ITER="${MAX_ITER:-8}"
DONE_MARKER="${DONE_MARKER:-LOOP_DONE}"
VERIFY_CMD="${VERIFY_CMD:-}"
MAX_CONSEC_FAIL="${MAX_CONSEC_FAIL:-3}"
MAX_CONSEC_VERIFY_FAIL="${MAX_CONSEC_VERIFY_FAIL:-5}"

# リポジトリルートへ移動（このスクリプトは loop/ 配下にある想定）
cd "$(dirname "$0")/.."

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE (cwd=$PWD)" >&2
  exit 1
fi

branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo '?')"

echo "== Closed Single-Agent Loop =="
echo "cwd     : $PWD"
echo "branch  : $branch"
echo "agent   : $AGENT_CMD"
echo "prompt  : $PROMPT_FILE"
echo "maxiter : $MAX_ITER"
echo "marker  : $DONE_MARKER"
echo "verify  : ${VERIFY_CMD:-<未設定！ 品質ゲート無しは危険>}"
echo

# 保護ブランチ直走を防ぐ（ループはコミットを重ねるため feature ブランチで）。
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo "ERROR: 保護ブランチ($branch)です。feature ブランチへ切り替えてから実行してください。" >&2
  exit 1
fi

if [[ -z "$VERIFY_CMD" ]]; then
  echo "WARNING: VERIFY_CMD が空です。品質ゲート無しではループが壊れた変更を緑として進めます。" >&2
fi

# 既定エージェント（claude）は無人実行のため認証が必須。空回りする前に fail-fast する。
# （ANTHROPIC_API_KEY = API 課金 / CLAUDE_CODE_OAUTH_TOKEN = Pro/Max サブスクの `claude setup-token`）
if [[ "$AGENT_CMD" == claude* && -z "${ANTHROPIC_API_KEY:-}" && -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  echo "ERROR: ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN のどちらも未設定です。無人の claude -p は認証できません。" >&2
  exit 2
fi

consecutive_fail=0
consecutive_verify_fail=0

for ((i = 1; i <= MAX_ITER; i++)); do
  echo "---- iteration $i / $MAX_ITER ($(date '+%H:%M:%S')) ----"

  # 毎周フレッシュなコンテキストでエージェントを起動。
  if ! output="$($AGENT_CMD < "$PROMPT_FILE")"; then
    consecutive_fail=$((consecutive_fail + 1))
    echo "agent invocation failed on iteration $i (consecutive=$consecutive_fail/$MAX_CONSEC_FAIL)。"
    # サーキットブレーカ: 連続失敗は API/セッション制限・障害とみなし停止（MAX_ITER 分の空回り防止）。
    if [[ "$consecutive_fail" -ge "$MAX_CONSEC_FAIL" ]]; then
      echo "== $consecutive_fail 連続でエージェント起動に失敗。停止します（API/セッション制限・障害の可能性）。 =="
      exit 2
    fi
    continue
  fi
  consecutive_fail=0
  echo "$output"

  # 外部品質ゲート（closed loop の二重安全網）。
  if [[ -n "$VERIFY_CMD" ]]; then
    echo "-- VERIFY: $VERIFY_CMD"
    if ! bash -c "$VERIFY_CMD"; then
      consecutive_verify_fail=$((consecutive_verify_fail + 1))
      echo "VERIFY failed on iteration $i (consecutive=$consecutive_verify_fail/$MAX_CONSEC_VERIFY_FAIL) — 次周で再挑戦します。"
      # サーキットブレーカ: VERIFY が連続で失敗＝ループがゲートに詰まっている可能性。暴走を止める。
      if [[ "$consecutive_verify_fail" -ge "$MAX_CONSEC_VERIFY_FAIL" ]]; then
        echo "== VERIFY が $consecutive_verify_fail 連続で失敗。ループが詰まっている可能性が高いので停止します。loop/MEMORY.md の Open を確認してください。 =="
        exit 3
      fi
      continue
    fi
    consecutive_verify_fail=0
  fi

  # 停止サイン検出: 行全体がマーカーと一致する場合のみ（説明文中の言及で誤検出しないよう厳格化）。
  if grep -qE "^[[:space:]]*${DONE_MARKER}[[:space:]]*$" <<< "$output"; then
    echo
    echo "== $DONE_MARKER detected on iteration $i. Loop complete. =="
    exit 0
  fi
done

echo
echo "== Reached MAX_ITER ($MAX_ITER) without $DONE_MARKER. Stopping. =="
echo "loop/MEMORY.md の Open を確認し、必要なら ./loop/run.sh を再実行してください。"
exit 1
