# ARCHITECTURE — 技術スタックとフォルダ構成

> エージェントが DISCOVER を高速化するためのプロジェクト知識。毎周ゼロから推測させない。
> ※ ループの作業ディレクトリ（cwd）は**リポジトリルート**。ループ用ドキュメントは `loop/` 配下。

## このリポジトリの性質

Claude Code の **プラグイン・マーケットプレイス**。アプリケーションのビルド/起動/ランタイムは無い。
中身は **Markdown（skill/agent 定義）・JSON（マーケット/プラグイン定義）・シェルスクリプト**。
したがって「実行時 smoke」は存在せず、VERIFY は**静的検査**（JSON 妥当性・shell 構文・frontmatter）で行う。

## スタック

- 主要フォーマット: Markdown（frontmatter 付き SKILL.md / agent .md）、JSON、Bash スクリプト
- パッケージマネージャ/ビルド: **なし**（`package.json` 無し）
- 検証に使えるツール: `jq`（JSON）、`bash -n`（shell 構文）、`node` / `deno`（必要なら）
- GitHub 操作: `gh` CLI（認証済み。issue 取得・コメント・ラベル操作・push）

## 主要ディレクトリ

```
.claude-plugin/marketplace.json           マーケットプレイス定義（プラグイン一覧）
plugins/hidekingerz/
  .claude-plugin/plugin.json               プラグイン定義
  skills/<name>/SKILL.md                    各スキル（frontmatter: name/description）
  skills/<name>/{assets,references}/...     スキルの付属ファイル
  agents/<name>.md                          サブエージェント定義（frontmatter 付き）
loop/                                        このループの設定（LOOP_PROMPT/VISION/ARCHITECTURE/RULES/MEMORY/run.sh/verify.sh）
```

## 重要な慣習

- SKILL.md と agents/*.md は先頭に YAML frontmatter（`---` … `---`、最低 `name` と `description`）を持つ。
- `marketplace.json` は `plugins` 配列で各プラグインの `source`（相対パス）を指す。
- スキルの付属スクリプト（`assets/*.sh`）は POSIX/bash として構文が通ること。
- 変更は該当プラグイン配下に閉じる。無関係な横断変更をしない。

## ビルド / 実行 / 検証コマンド

- インストール: 不要
- **VERIFY（毎周の品質ゲート＝速い静的検査）**: `./loop/verify.sh`
  - 全 JSON を `jq empty` で構文検証（marketplace.json / 各 plugin.json）
  - 全 `*.sh` を `bash -n` で構文検証
  - 全 SKILL.md / agents/*.md に frontmatter（`name` / `description`）が存在するか検証
- 完了ゲートの追加項目: **なし（ランタイム smoke 無し）**。意味的正しさはマージ前の人間レビュー
  （`/code-review` 等、maker/checker 分離）で担保する。

## GitHub issue の扱い（このループ固有）

- 対象取得:
  `gh issue list --repo hidekingerz/claude-plugins --state open --label auto-fix --json number,title,body,labels`
- 着手時: 選んだ issue に `loop-wip` を付ける（他周/他者との二重着手を避ける目印）。
- 解消時: 変更を1コミット → `git push`（feature ブランチ）→ issue にコメント（要約・ブランチ名）→
  `loop-wip` と `auto-fix` を外す。**issue の close は人間**（PR マージ時に閉じる）。
- 検証不能/判断保留: `loop-needs-human` を付け、`loop-wip` を外し、理由を issue コメントと
  `loop/MEMORY.md` の Open に残す。

## MCP による実行時検証

このリポジトリはランタイム/GUI を持たないため **MCP 実行時検証は不要**（該当なし）。
