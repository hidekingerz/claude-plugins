---
name: single-agent-loop-setup
description: >-
  対象リポジトリに「single-agent-loop（catch-all-favorite 系）」＝自律コーディングループを初期
  セットアップするスキル。ハードニング済みの run.sh と VISION/ARCHITECTURE/RULES/MEMORY/
  LOOP_PROMPT 雛形を配置し、実 DoD に一致した VERIFY ゲートを設計し、feature ブランチを切るまでを
  支援する。ユーザーが「ループをセットアップして」「自律ループ/single-agent loop/ralph loop を
  作りたい」「このリポジトリで自走エージェントを回したい」「移行/大規模リファクタを自律ループで
  進めたい」「loop/ を作って」等と言ったら、たとえ "skill" の語が無くても必ずこのスキルを使うこと。
  ループの実行(./loop/run.sh)はユーザーが行う（このスキルはセットアップまで）。
---

# single-agent-loop セットアップ

対象リポジトリに**自律コーディングループ**を初期セットアップする。ループは `claude -p` を毎周
フレッシュなコンテキストで回し、記憶は `loop/MEMORY.md` が担い、`VERIFY` ゲートを通り `LOOP_DONE` が
出るまで小タスクを反復する（DISCOVER→PLAN→EXECUTE→VERIFY→ITERATE）。

このスキルは**セットアップまで**を担う（実行 `./loop/run.sh` はユーザー）。最重要は **VERIFY/完了
ゲートを「本当の DoD」に一致させること**（理由と落とし穴は `references/gate-design.md` 必読）。

## 位置づけ — 組み込みのループ機能との使い分け

Claude Code 公式の分類（turn-based / goal-based / time-based / proactive）でいうと、この skill の
ループは **goal-based ループ（ゴール達成 or 反復上限で停止）の自前実装**。組み込み機能で足りる場面
ではそちらが簡単なので、先に使い分ける（複雑なループが不要なタスクに持ち出さない）:

- **対話中の小〜中タスク**（完了基準が明確・数ターンで済む）→ 組み込みの **`/goal`**（評価モデルが
  停止判定・「stop after 5 tries」等の上限指定可）。
- **定期実行・外部システムの監視**（PR の CI 対応、定時バッチ等）→ **`/loop`**（ローカル・時間間隔）
  / **`/schedule`**（クラウド routine）。
- **この skill の出番**: **無人・使い捨てコンテナ隔離・egress 制限・毎周フレッシュ文脈 + MEMORY
  引き継ぎが必要な長丁場**（移行・大規模リファクタ等）。git 規律（1タスク=1コミット・feature
  ブランチ）と VERIFY ゲートをリポジトリ内ファイルとして固定し、セッションを跨いで再開できるのが差分。

## いつ使うか

- 「ループをセットアップして」「自律ループ/ralph loop を作りたい」「自走エージェントを回したい」
- 「X→Y への移行/大規模リファクタ/全 N ファイルの一括変更を自律で進めたい」
- 「loop/ 雛形を置いて」

## セットアップ手順（この順で実施。各項目を TodoWrite に積むとよい）

### 1. スコープを詰める（ユーザーと）

- **ゴール**（1〜2文）と **DoD（完了の定義）** を聞く。DoD は検証可能な箇条書きに落とす。
- ★**「本当に完成した状態」を DoD にする。** ビルド/単体が緑なだけで足りないなら「実際に動作する」
  まで DoD に含める（GUI/ランタイムなら起動して操作できること）。
- このリポジトリの **VERIFY コマンド**（lint/typecheck/test 等）と、完了ゲートに足すべき重い検査
  （ランタイム/GUI smoke、禁止 import の grep ゲート等）を把握する。`references/gate-design.md` 参照。

### 2. 雛形を配置

`assets/` の6ファイルを対象リポジトリの `loop/` に配置する:

```bash
mkdir -p loop
cp "${CLAUDE_SKILL_DIR}/assets/run.sh"          loop/run.sh
cp "${CLAUDE_SKILL_DIR}/assets/LOOP_PROMPT.md"  loop/LOOP_PROMPT.md
cp "${CLAUDE_SKILL_DIR}/assets/VISION.md"       loop/VISION.md
cp "${CLAUDE_SKILL_DIR}/assets/ARCHITECTURE.md" loop/ARCHITECTURE.md
cp "${CLAUDE_SKILL_DIR}/assets/RULES.md"        loop/RULES.md
cp "${CLAUDE_SKILL_DIR}/assets/MEMORY.md"       loop/MEMORY.md
chmod +x loop/run.sh
```

`run.sh` は**ハードニング済み**（堅牢な LOOP_DONE 検出・連続失敗サーキットブレーカ・保護ブランチ
ガード・VERIFY 空の警告）。**書き換えず使う**のが基本。

### 3. 雛形の `{{...}}` をこのプロジェクト向けに記入

> 配置済みファイルを Edit/Write する際は、一度 Read してから編集する（ハーネスによっては Read 前の
> 編集が拒否される）。あるいは `assets/` の雛形を直接 Read し、埋めた内容を `loop/` へ Write する。
> どちらの方式でも、プロジェクト型に合わない例（lib/CLI なら GUI smoke/MCP 行）は削除する。

- **VISION.md**: ゴール / DoD / **完了ゲート（毎周 VERIFY と LOOP_DONE 条件を2層で）** / スコープ外。
- **ARCHITECTURE.md**: スタック・主要ディレクトリ・慣習・**VERIFY/完了ゲート/起動コマンド**・参照元。
- **RULES.md**: プロジェクト固有の禁止事項を追記（参照専用ディレクトリ等）。
- **MEMORY.md**: 通常そのまま（オペレータ注記の運用説明入り）。スキャフォールドで先に1タスク分
  作るならその記録を Done に。

### 4. VERIFY ゲートを実 DoD に一致させる（核心）

- **毎周の VERIFY**（`run.sh` の `VERIFY_CMD`）= 速い静的検査（fmt/lint/typecheck/unit）。途中状態でも
  緑にできるものに限る。
- **完了ゲート**（`LOOP_DONE` の条件、VISION に明記）= VERIFY + grep ゲート + **ランタイム/GUI smoke**
  + 結合テスト。これら全緑で初めて完了。
- GUI/ランタイムを伴うなら、**ヘッドレス起動して実行時エラーを検知する smoke** を用意する
  （`references/gate-design.md` のパターン）。これが無いとループは「緑のまま壊れたもの」を出荷する。
- **MCP での GUI/ランタイム検証も可**: Playwright / chrome-devtools 等の MCP で実アプリを操作して
  コンソールエラー・要素の有無を観測できる（bash smoke より強力）。ただし `run.sh` の `VERIFY_CMD`
  は **bash 専用**なので、MCP 検証は**エージェント自身の VERIFY 段/完了ゲートに「MCP で〜を検証」と
  明記して行わせる**（bash に乗せたいなら CLI でラップ）。認証が要る MCP は無人実行で使えない点に
  注意。詳細は `references/gate-design.md`。

### 5. feature ブランチを切る

ループはコミットを重ねるため**保護ブランチ直走は不可**。`run.sh` も `main`/`master` を拒否する。

```bash
git switch -c feat/<topic>
```

（保護ブランチへの直 commit を PreToolUse フック等で別途ブロックしているプロジェクトもある。その
場合はブランチ作成と commit を別コマンドに分ける。）

### 6. 緑のベースラインを用意（推奨）

ループは「VERIFY 緑」でしかコミットしない。最初に**最小の通るテスト**（参照実装1つ等）を置いて
`VERIFY_CMD` がグリーンであることを確認しておくと、初周から安定する。

### 7. 引き継ぎ（実行はユーザー）

ユーザーに渡す情報:

- **起動**: リポジトリルートで
  `VERIFY_CMD="<品質ゲート>" MAX_ITER=8 ./loop/run.sh`
  （`AGENT_CMD` 既定は `claude -p --dangerously-skip-permissions -`。無人ループのため権限確認を
  バイパスする。）
- ★**安全網の実効範囲を取り違えない**: feature ブランチ+RULES+VERIFY+ブレーカは「git コミット」と
  「ループ暴走」を守るだけで、**ファイルシステム・秘密情報・ネットワークは守らない**。
  `--dangerously-skip-permissions` 下のエージェントは実行ユーザー権限で任意コマンドを実行でき、
  リポジトリ内の信頼できないテキスト（依存 README 等）経由のプロンプトインジェクションにも曝される。
  **ホスト環境の隔離が本来の防御**。詳細と対策は `references/gate-design.md` の「8. 無人実行の権限と
  サンドボックス」必読。手軽な隔離は下記「Docker 隔離実行」。
- **MAX_ITER**: 長丁場は再実行前提で 8 程度から。`MAX_CONSEC_FAIL`（既定3）で session 制限の空回りを停止。
- **方向付け**: 途中で軌道修正したいときは `loop/MEMORY.md` の Open 最上部に `[operator/...]` 注記を
  差し込む（次周のエージェントが最優先で読む）。
- **節目で人間検証**: GUI の「動く/操作できる」等、ゲートで観測できないものは目視確認する。
- **session/API 制限とコスト**: ループは使用量の増幅器（メイン + 毎周の `claude -p`）。バッチを
  小さく、effort は必要な周だけ。定型的な反復周は `AGENT_CMD` で小さいモデルに落とし、判断の重い所
  （checker 等）だけ上位モデルに（モデル・ルーティング）。**初回は `MAX_ITER=2〜3` のパイロット**で
  1周あたりの消費を実測してから本走する。詳細は `references/gate-design.md`「6.」。

## Docker 隔離実行（推奨: 無人 + skip-permissions のとき）

`--dangerously-skip-permissions` の無人ループは実行ユーザー権限で任意コマンドを実行し、リポジトリ内の
信頼できないテキスト経由のプロンプトインジェクションにも曝される。feature ブランチ/RULES/VERIFY は
これらを防がない（`references/gate-design.md`「8.」）。**ホスト隔離が本来の防御**。同梱の Docker
テンプレートで、リポジトリだけをマウントした使い捨てコンテナに閉じ込められる。

1. 追加2ファイルを `loop/` に配置:

   ```bash
   cp "${CLAUDE_SKILL_DIR}/assets/Dockerfile"        loop/Dockerfile
   cp "${CLAUDE_SKILL_DIR}/assets/run-in-docker.sh"  loop/run-in-docker.sh
   chmod +x loop/run-in-docker.sh
   ```

2. `loop/Dockerfile` の印の箇所に**プロジェクトのツールチェーン**（VERIFY_CMD が使うもの: pnpm /
   Python / Deno / Rust 等）を追記する。node/npm だけで VERIFY できるなら追記不要。
3. 実行（`run-in-docker.sh` がビルド→リポジトリだけをマウント→コンテナ内で `loop/run.sh` を起動）:

   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...            # 認証その1: API 課金（Console のキー）
   # export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat...  # 認証その2: Pro/Max サブスク（`claude setup-token` で発行）
   VERIFY_CMD="<品質ゲート>" MAX_ITER=8 ./loop/run-in-docker.sh   # ↑どちらか一方があればよい
   ```

隔離の要点と限界:

- ホームの機密（`~/.ssh` `~/.aws` `~/.config/gh` 等）はマウントしない → エージェントから見えない。
  破壊的操作・インジェクションの影響はおおむねコンテナ内に閉じるが、**リポジトリへの変更はホストに
  残り、その中には「後でホストで実行されるファイル」が含まれる**（`.git/hooks`・`.git/config`・
  `loop/*.sh`。改変されると次にホストで git やループを叩いた時にホスト側でコードが走る）。
  `run-in-docker.sh` は実行前後でこれらのハッシュを比較し、変化があれば警告して exit 4 で終える
  （**検知であって防止ではない**）。警告が出たら差分を確認するまでホストで git 操作をしないこと。
  compose 経由にはこのチェックが無いので、実行後に `.git/hooks`・`.git/config`・`loop/` の差分を
  目視確認する。
- 認証は無人のため env で渡す。API 課金なら `ANTHROPIC_API_KEY`、Pro/Max サブスクなら
  `claude setup-token` で発行した `CLAUDE_CODE_OAUTH_TOKEN`（どちらか一方）。ループに不要な資格情報は渡さない。
- root コンテナで `--dangerously-skip-permissions` を通すため `IS_SANDBOX=1` を設定済み（ラッパー内）。
- **ネットワークは完全遮断できない**（Anthropic API・パッケージレジストリに到達が要る）。宛先を絞るなら
  egress proxy を用意し `LOOP_NETWORK` で指定する。無制限アウトバウンドが気になる場合の残存リスク。
- Linux でマウント成果物の所有者を保ちたい場合は `LOOP_DOCKER_FLAGS='--user 1000:1000'` 等を渡す
  （その際は Dockerfile 側の `safe.directory`/HOME 調整が要ることがある。macOS の Docker Desktop は不要）。

### フロントエンド + MCP 実行時検証（Vite 系）

フロントの「実際に描画され操作できる」を観測するには、bash smoke より **MCP で実画面を操作**するのが
強力（`references/gate-design.md`「1.」）。ただし MCP は `run.sh` の bash VERIFY_CMD では呼べず、
**エージェント（`claude -p`）自身が完了ゲートで実施**する。隔離コンテナでこれを可能にする一式:

1. ブラウザ入りイメージと MCP 設定を配置:

   ```bash
   cp "${CLAUDE_SKILL_DIR}/assets/Dockerfile.frontend"    loop/Dockerfile.frontend
   cp "${CLAUDE_SKILL_DIR}/assets/chromium-seccomp.json"  loop/chromium-seccomp.json   # 下の run-in-docker.sh コマンドの --security-opt seccomp= が参照
   cp "${CLAUDE_SKILL_DIR}/assets/mcp.json"               .mcp.json   # ★リポジトリルート（claude -p が読む）
   ```

2. `Dockerfile.frontend` の印の箇所に Vite のツールチェーン（pnpm 等）を必要なら追記。Playwright
   バージョンはプロジェクトの `@playwright/test` に合わせる。
3. `loop/ARCHITECTURE.md` の「MCP による実行時検証」節に **dev/preview サーバの起動→待機→検証→停止**
   手順と使う MCP を記入。`loop/VISION.md` の完了ゲートに MCP 検証の項目（実際に画面を開いて
   **変更 UI を操作・before/after スクリーンショット・コンソールエラー0件**、性能が DoD なら CWV
   トレースまで）を残す（雛形にプレースホルダあり）。
4. `Dockerfile.frontend` を使って実行（`run-in-docker.sh` / compose どちらも `LOOP_DOCKERFILE` で選択）:

   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...   # または CLAUDE_CODE_OAUTH_TOKEN（Pro/Max。`claude setup-token`）
   LOOP_DOCKERFILE=Dockerfile.frontend \
     LOOP_DOCKER_FLAGS='-v /workspace/node_modules --security-opt seccomp=loop/chromium-seccomp.json' \
     VERIFY_CMD='[ node_modules/.package-lock.json -nt package-lock.json ] || npm ci; npm run lint && npm run typecheck && npm test' \
     ./loop/run-in-docker.sh
   # egress 制限も併用するなら（node_modules 隔離は docker-compose.yml に組み込み済み・下記④）:
   # LOOP_DOCKERFILE=Dockerfile.frontend \
   #   VERIFY_CMD='[ node_modules/.package-lock.json -nt package-lock.json ] || npm ci; npm run lint && npm run typecheck && npm test' \
   #   docker compose -f loop/docker-compose.yml up --build --abort-on-container-exit
   ```

   - `LOOP_DOCKER_FLAGS` の `-v /workspace/node_modules` は **node_modules をコンテナ専用の匿名
     ボリュームに隔離**する（★重要）。これが無いと、bind mount した host の node_modules（macOS/arm64
     の native バイナリ）を Linux コンテナが使って壊れる。匿名ボリュームは `Dockerfile.frontend` で
     pwuser 所有に初期化済み（これが無いと root 所有で作られ `npm ci` が EACCES で失敗する）。
   - インストールは **`npm install` でなく `npm ci`**（lockfile を書き換えず churn を出さない。
     `references/gate-design.md`「5.」）。ガード `[ node_modules/.package-lock.json -nt package-lock.json ]`
     は **lockfile が変わった時だけ再 install** する（毎周スキップだと、ループが依存を追加した周に
     install 漏れ → 壊れたまま緑になる）。`npm ci` は **package-lock.json が commit 済み**である前提
     （無いリポでは `npm install` に置き換える）。
   - `--security-opt seccomp=loop/chromium-seccomp.json` は chrome-devtools MCP を sandbox 有効で
     動かすため（Playwright MCP 主なら無くても可）。
   - 認証: `claude setup-token` は**素のトークンでなく説明文込みで出力**されるので
     `export X=$(claude setup-token)` では丸ごと入って失敗する。**実行してトークン部分だけコピー**して
     `export CLAUDE_CODE_OAUTH_TOKEN=<paste>` すること。無人で回す場合は gitignore した `loop/.env`
     （`CLAUDE_CODE_OAUTH_TOKEN=...`）に置き、`set -a; . loop/.env; set +a` で読ませると扱いやすい。
   - **配信URLを変える設定（Vite の `base` 等）を常時入れると、ループの MCP 検証（`localhost:PORT/` を
     開く）が 404 で壊れる**。GitHub Pages のサブパス等はデプロイビルド限定に gate する
     （例: `base: process.env.VITE_BASE ?? "/"` にして deploy 時だけ `VITE_BASE` を渡す）。

要点と落とし穴:
- **ブラウザはイメージに焼き込み済み**（Playwright の Chromium。arm64/x64 両対応）。実行時にブラウザを
  DL しないので egress allowlist への追加は不要。`.mcp.json` は Playwright MCP と chrome-devtools MCP を
  両方定義し、**両方とも焼き込み済み Chromium（/usr/local/bin/pw-chromium）を明示指定**する
  （chrome-devtools は `--executablePath`、playwright は `--executable-path`。★playwright 側の指定を
  省くと、同梱 playwright が期待する別リビジョンを探して「Browser is not installed」で起動不能になる。
  Apple Silicon 対策で google-chrome は使わない）。堅牢さでは **Playwright MCP を主**にするのが無難。
- ブラウザ→dev サーバは **localhost** アクセス。compose の `NO_PROXY=localhost,127.0.0.1` でプロキシを
  迂回する（egress 制限下でも動く）。フロントが外部 API を叩くなら、その宛先を `allowlist.yaml` に追加。
- headless では**エージェントが dev サーバの起動・ポート待ち・停止まで**担う。ARCHITECTURE にその手順を
  具体的に書かないと、サーバ未起動のまま「検証した」と誤判定しうる。
- **認証が要る MCP は無人 headless では使えない**（Playwright/chrome-devtools は認証不要で可）。
- headless の `claude -p` に**プロジェクトの `.mcp.json` を読ませるには承認が要る**。無人実行では
  対話承認できないため、リポジトリの `.claude/settings.json` に
  `{ "enableAllProjectMcpServers": true }` を置いて自動承認する（full-loop 検証で動作確認済み）。
- `.mcp.json` はリポジトリルートに置くため、**ホストで対話的に claude を使う時もホスト側で同じ MCP
  サーバが起動される**（脆弱性ではないが副作用として認識しておく。ホストに Playwright/Chrome が
  無ければ単に接続失敗するだけ）。
- ブラウザのサンドボックスは非 root（pwuser）で有効のまま動かす。★ただし **Docker 既定の seccomp は
  unprivileged user namespace を塞ぐ**ため、sandbox 有効で起動する chrome-devtools MCP は素の
  docker run では "Target closed" で失敗する（playwright MCP は既定で chromium sandbox を使わず影響なし）。
  対処は Playwright 公式の seccomp プロファイル（**`assets/chromium-seccomp.json` として同梱済み**。
  Docker 既定 + userns 許可のみの緩和版）を渡す:
  - compose 経路: `loop/chromium-seccomp.json` に配置すれば **security_opt で適用済み**（テンプレートに
    記載済み。in-loop で chrome-devtools MCP の実操作まで動作検証済み）。
  - `run-in-docker.sh` 経路: `LOOP_DOCKER_FLAGS='--security-opt seccomp=loop/chromium-seccomp.json'`。
  最後の手段は chrome-devtools に `--chrome-arg=--no-sandbox` を足す（ブラウザ隔離が弱まる）。

### E2E で ホスト/外部バックエンドに繋ぐ（隔離との折り合い）

★**コンテナ内 claude からホストの Chrome を操作するのは非推奨。** ホスト Chrome の CDP を晒すと、
ログイン中セッション・Cookie を自律エージェントに丸ごと明け渡し、閉じた隔離を開け直す（lethal
trifecta の再来）。**ブラウザはコンテナ内 Chromium のまま**、バックエンドへの到達だけを開ける。

バックエンドの置き場所で方針が変わる:

- **理想: バックエンドも compose のサービスにして `loopnet`(internal) に載せる。** ブラウザも API も
  内部ネットワークで完結し、隔離を保ったまま E2E できる（最も無傷）。同一リポ/コンテナ化可能なら一択。
- **外部ステージング（URL がある）**: egress-compose のまま `allowlist.yaml` にそのドメインを1行足す。
  ブラウザに squid を使わせるため `.mcp.json` の Playwright に
  `--proxy-server http://egress-proxy:3128` と `--proxy-bypass localhost` を足す。fail-closed を崩さない。
- **ホスト常駐バックエンド**: `internal` 網ではホストへの経路が無い。`run-in-docker.sh`（bridge 経路）を
  **`HOST_BACKEND=1`** 付きで実行し、コンテナから `http://host.docker.internal:<PORT>` で到達する
  （既定は無効。この経路が要る実行でだけ有効化する。macOS の Docker Desktop は元々解決できるため
  主に Linux 向けのスイッチ）。**この場合 egress allowlist は外れる**が、**ファイルシステム隔離・
  ホームの秘密を渡さない**という主防御は維持される。「fs/秘密の隔離が主、egress allowlist は多層防御の
  外側」と割り切り、E2E に必要な分だけ後者を緩める判断。

残存リスクと運用:
- ホスト/外部バックエンドに繋ぐ = **その宛先に対しては隔離が空く**。繋ぐ先は**使い捨ての dev 環境/dev DB**に
  限り、本番・共有ステージングの管理エンドポイントは避ける（自律エージェントが叩きうる）。
- **重い実バックエンド E2E は毎周の VERIFY に入れない。** 完了ゲート（LOOP_DONE 前）か節目の人間検証に
  置く（`references/gate-design.md`「2.」「4.」）。毎周は fmt/lint/typecheck/unit + 軽い MCP スモークまで。

### egress 制限（上級: 無制限アウトバウンドが気になるとき）

`run-in-docker.sh` の既定は通常の bridge ＝アウトバウンド無制限。**送信先を allowlist に絞りたい**
場合は同梱の compose テンプレートを使う。loop コンテナを **internal ネットワークにのみ**接続し、
唯一の出口を allowlist プロキシ(squid)経由に限定する（**fail-closed**: プロキシを通らない通信は
物理的に届かないので、ツールが proxy 設定を無視しても漏れではなく接続失敗になる）。

1. 追加3ファイルを配置（プロキシ設定は `loop/proxy/` に置く）:

   ```bash
   cp "${CLAUDE_SKILL_DIR}/assets/docker-compose.yml"     loop/docker-compose.yml
   cp "${CLAUDE_SKILL_DIR}/assets/chromium-seccomp.json"  loop/chromium-seccomp.json  # compose が security_opt で参照
   mkdir -p loop/proxy
   cp "${CLAUDE_SKILL_DIR}/assets/squid.conf"             loop/proxy/squid.conf
   cp "${CLAUDE_SKILL_DIR}/assets/allowlist.yaml"         loop/proxy/allowlist.yaml
   ```

2. `loop/proxy/allowlist.yaml` に**このプロジェクトが必要とする宛先だけ**を残す/追記する
   （既定は Anthropic API・npm・GitHub。PyPI/crates 等はプロジェクトに応じて追加）。起動時に
   `allowlist-gen` サービスが yq で squid 用のリストへ変換する（人間が触るのは YAML だけ）。
3. 実行:

   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...   # または CLAUDE_CODE_OAUTH_TOKEN（Pro/Max。`claude setup-token`）。
                                          # loop/.env に書いてもよい（compose が自動で読む）
   VERIFY_CMD="<品質ゲート>" MAX_ITER=8 \
     docker compose -f loop/docker-compose.yml up --build --abort-on-container-exit
   ```

補足:
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` を compose で設定済み（テレメトリ等を抑止し
  allowlist を最小化）。それでも claude が繋がらない時は
  `docker compose -f loop/docker-compose.yml exec egress-proxy tail -20 /var/log/squid/access.log`
  で `TCP_DENIED` の宛先を確認し `allowlist.yaml` に追記する（親子重複させないこと。squid が
  FATAL で起動しなくなる）。
- HTTPS は CONNECT の宛先ホスト名で判定するため**証明書注入(MITM)なし**。ドメイン単位の許可。
  ポートは 80/443 のみ許可（`Safe_ports`）。
- 残存経路: `internal` ネットワークでも Docker 内蔵 DNS はホストリゾルバへ転送するため、**DNS クエリに
  データを載せた持ち出しは理論上可能**（loop 側の名前解決は本来不要。squid が CONNECT 先を自前解決する）。
  完全に塞ぐ要件があるならホスト側 DNS の egress 監視で補う。
- 停止・後片付けは `docker compose -f loop/docker-compose.yml down`。

## 設計原則（必読）

このスキルの肝は手順より**原則**にある。実戦の教訓（白画面で誤完了した実例、二層ゲート、
ランタイム smoke の作り方、未コミット救出、session 制限、オペレータ注記）は
**`references/gate-design.md` を必ず読むこと**。

要約: **ゲートがループそのもの。** ループはゲートに最適化するので、ゲートを実 DoD に一致させない
限り "緑の嘘" が出る。人間の主戦場は実装ではなく**ゲート設計と、ゲートが見えない所の検証**。
