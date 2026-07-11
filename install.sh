#!/usr/bin/env bash
#
# install.sh — このリポジトリのスキルを Codex / opencode 向けにインストールする
#
# Codex と opencode はどちらも Agent Skills 標準（SKILL.md）をサポートし、
# 共通のユーザースキルディレクトリ ~/.agents/skills/ を読み込む:
#   - Codex:    ~/.agents/skills/<name>/SKILL.md（$skill-name で明示起動 or description で自動発動）
#   - opencode: ~/.agents/skills/<name>/SKILL.md（skill ツール経由で発動）
#
# さらに opencode 向けには tech-doc-writer / test-writer をサブエージェント
# （~/.config/opencode/agents/*.md、@名前 で起動）としても生成する。
#
# 使い方:
#   ./install.sh              # スキル + opencode サブエージェントをインストール
#   ./install.sh --skills-only  # スキルのみ（opencode を使わない場合）
#   ./install.sh --uninstall  # このスクリプトが入れたものを削除
#
# 環境変数で配置先を上書き可能:
#   AGENTS_SKILLS_DIR    （既定: ~/.agents/skills）
#   OPENCODE_AGENTS_DIR  （既定: ~/.config/opencode/agents）

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
OPENCODE_AGENTS_DIR="${OPENCODE_AGENTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents}"

SKILL_SRC_DIRS=(
  "$REPO_DIR/plugins/hidekingerz/skills"
  "$REPO_DIR/portable/skills"
)

# opencode サブエージェントとして portable/skills から生成するもの
OPENCODE_SUBAGENTS=(tech-doc-writer test-writer)

MODE="install"
SKILLS_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE="uninstall" ;;
    --skills-only) SKILLS_ONLY=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 1 ;;
  esac
done

installed_skill_names() {
  local dir
  for dir in "${SKILL_SRC_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    for skill in "$dir"/*/; do
      basename "$skill"
    done
  done
}

if [ "$MODE" = "uninstall" ]; then
  while IFS= read -r name; do
    if [ -d "$AGENTS_SKILLS_DIR/$name" ]; then
      rm -rf "$AGENTS_SKILLS_DIR/$name"
      echo "removed  $AGENTS_SKILLS_DIR/$name"
    fi
  done < <(installed_skill_names)
  for name in "${OPENCODE_SUBAGENTS[@]}"; do
    if [ -f "$OPENCODE_AGENTS_DIR/$name.md" ]; then
      rm -f "$OPENCODE_AGENTS_DIR/$name.md"
      echo "removed  $OPENCODE_AGENTS_DIR/$name.md"
    fi
  done
  echo "uninstall complete."
  exit 0
fi

# --- スキル: ~/.agents/skills/ へコピー（Codex / opencode 共通）------------------
mkdir -p "$AGENTS_SKILLS_DIR"
for dir in "${SKILL_SRC_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  for skill in "$dir"/*/; do
    name="$(basename "$skill")"
    if [ ! -f "$skill/SKILL.md" ]; then
      echo "skip     $name (SKILL.md なし)" >&2
      continue
    fi
    rm -rf "${AGENTS_SKILLS_DIR:?}/$name"
    cp -R "$skill" "$AGENTS_SKILLS_DIR/$name"
    echo "skill    $AGENTS_SKILLS_DIR/$name"
  done
done

# --- opencode サブエージェント: portable/skills の本文から生成 -------------------
opencode_agent_description() {
  case "$1" in
    tech-doc-writer)
      echo "README・APIドキュメント・アーキテクチャ文書・セットアップガイドなど技術文書の作成・改善を行うサブエージェント" ;;
    test-writer)
      echo "ユニットテスト・インテグレーションテストの作成とテストカバレッジ改善を行うサブエージェント" ;;
    *)
      echo "hidekingerz/claude-plugins のサブエージェント" ;;
  esac
}

if [ "$SKILLS_ONLY" -eq 0 ]; then
  mkdir -p "$OPENCODE_AGENTS_DIR"
  for name in "${OPENCODE_SUBAGENTS[@]}"; do
    src="$REPO_DIR/portable/skills/$name/SKILL.md"
    [ -f "$src" ] || { echo "skip     $name (portable/skills に見つからない)" >&2; continue; }
    dst="$OPENCODE_AGENTS_DIR/$name.md"
    {
      printf -- '---\n'
      printf 'description: %s\n' "$(opencode_agent_description "$name")"
      printf 'mode: subagent\n'
      printf -- '---\n\n'
      # SKILL.md の frontmatter（最初の --- ... ---）を除いた本文
      awk 'BEGIN{n=0} n<2 && /^---[[:space:]]*$/{n++; next} n>=2{print}' "$src"
    } > "$dst"
    echo "agent    $dst (opencode)"
  done
fi

echo
echo "install complete."
echo "  Codex:    \$skill-name で明示起動、または依頼内容に応じて自動発動します"
echo "  opencode: skill ツールで発動、サブエージェントは @tech-doc-writer / @test-writer"
echo "更新するときは git pull してからこのスクリプトを再実行してください。"
