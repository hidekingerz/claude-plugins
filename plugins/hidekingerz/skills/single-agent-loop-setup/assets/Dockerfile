# single-agent-loop 隔離実行用イメージ（テンプレート）
#
# 無人ループを「ホストから隔離した使い捨てコンテナ」で回すためのベース。
# claude -p --dangerously-skip-permissions は実行ユーザー権限で任意コマンドを実行するため、
# ホームの機密（~/.ssh 等）を触らせない・破壊的操作をコンテナ内に閉じ込めるのが狙い。
#
# ★プロジェクトのツールチェーン（VERIFY_CMD が使うもの）を下の印の箇所に追記して使う。
# 使い方は SKILL.md の「Docker 隔離実行」節、設計意図は references/gate-design.md の「8.」参照。

FROM node:22-bookworm-slim

# git（コンテナ内 commit に必須）と基本ツール（curl は HTTP smoke テスト等で使う）
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI（claude -p を無人実行するため）
# ★サプライチェーン対策: 運用に乗せる際はバージョンを固定する（例: @anthropic-ai/claude-code@2.1.39）
RUN npm install -g @anthropic-ai/claude-code

# マウントしたリポジトリを別ユーザー所有とみなして git が拒否する事故を防ぐ
RUN git config --global --add safe.directory /workspace

# --- ここにプロジェクトのツールチェーンを追記（VERIFY_CMD が使うものを入れる）-------------
# 例:
#   RUN corepack enable && corepack prepare pnpm@latest --activate        # pnpm
#   RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip \
#       && rm -rf /var/lib/apt/lists/*                                    # Python
#   （Deno / Rust / Go 等は各公式手順で。何も足さなければ node/npm だけで VERIFY できる前提）
# ------------------------------------------------------------------------------------------

WORKDIR /workspace
