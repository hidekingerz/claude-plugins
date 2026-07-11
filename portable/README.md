# portable/ — Codex / opencode 向け移植ファイル

ルートの `install.sh` が参照するディレクトリ。

- `skills/tech-doc-writer/`, `skills/test-writer/`
  `plugins/hidekingerz/agents/*.md`（Claude Code サブエージェント）を
  Agent Skills 標準（SKILL.md）に変換したもの。Codex / opencode では
  `~/.agents/skills/` にインストールされ、スキルとして発動する。
  opencode 用サブエージェント（`~/.config/opencode/agents/*.md`）は
  `install.sh` がこの SKILL.md の本文から生成するため、リポジトリには持たない。

保守メモ:

- 4つのスキル本体（`plugins/hidekingerz/skills/*/SKILL.md`）はツール中立に書かれており、
  移植コピーは持たない（`install.sh` がプラグインのディレクトリを直接コピーする）。
- `plugins/hidekingerz/agents/*.md` を更新したら、対応する `portable/skills/*/SKILL.md` にも
  同じ変更を反映すること（frontmatter と「エージェントメモリ」節の表現だけが意図的に異なる）。
