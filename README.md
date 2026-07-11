# claude-plugins

claude 用スキル置き場（Claude Code plugin marketplace）。
全スキル・エージェントを単一プラグイン `hidekingerz` に束ねている（vercel プラグインと同じ方式）。
スキルは `hidekingerz:<スキル名>` の名前で利用できる。

スキルは [Agent Skills 標準](https://agentskills.io)（SKILL.md）に沿ったツール中立な書き方に
してあるため、**Codex CLI / opencode でもそのまま使える**（下記「Codex / opencode で使う」参照）。

## 導入方法

Claude Code のセッション内で:

```
/plugin marketplace add hidekingerz/claude-plugins
/plugin install hidekingerz@hidekingerz
```

更新を取り込むとき:

```
/plugin marketplace update hidekingerz
```

### プロジェクトで自動有効化する（推奨）

チームの各プロジェクトリポジトリの `.claude/settings.json` に以下をコミットしておくと、
メンバーがそのリポジトリを開いて信頼するだけで自動的にインストール・有効化される:

```json
{
  "extraKnownMarketplaces": {
    "hidekingerz": {
      "source": {
        "source": "github",
        "repo": "hidekingerz/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "hidekingerz@hidekingerz": true
  }
}
```

## Codex / opencode で使う

Codex CLI と opencode はどちらも Agent Skills 標準（SKILL.md）をサポートしており、
共通のユーザースキルディレクトリ **`~/.agents/skills/`** を読み込む。
リポジトリを clone して `install.sh` を実行するだけでよい:

```bash
git clone https://github.com/hidekingerz/claude-plugins.git
cd claude-plugins
./install.sh
```

インストールされるもの:

- **`~/.agents/skills/`**（Codex / opencode 共通）
  - 4スキル: `single-agent-loop-setup` / `graphify` / `commit-push` / `obsidian-handwritten-note`
  - サブエージェントのスキル版: `tech-doc-writer` / `test-writer`（`portable/skills/` から）
- **`~/.config/opencode/agents/`**（opencode のみ。`--skills-only` でスキップ可）
  - `tech-doc-writer` / `test-writer` サブエージェント（`@tech-doc-writer` のように起動）

使い方:

- **Codex**: `$commit-push` のように `$スキル名` で明示起動。依頼内容が description に
  一致すれば自動発動もする。プロジェクト単位で使いたい場合はリポジトリの `.agents/skills/` に
  スキルディレクトリをコピーしてもよい
- **opencode**: 依頼内容に応じて `skill` ツール経由で自動発動する

更新は `git pull` してから `./install.sh` を再実行。削除は `./install.sh --uninstall`。

補足:

- Claude Code 固有の frontmatter（`disable-model-invocation` 等）は Codex / opencode では
  無視される。このため `commit-push` / `obsidian-handwritten-note` は Codex / opencode では
  自動発動もしうる（どちらも実行前にユーザー確認を挟む設計なので実害はない）
- `single-agent-loop-setup` の Docker 隔離テンプレートは Claude Code CLI（`claude -p`）を
  ループ内エージェントとして焼き込む前提。Codex / opencode でループ自体を回す場合の
  `AGENT_CMD` 差し替え手順は同スキルの「ループを Claude 以外のエージェント CLI で回す」節を参照

## 収録内容

### スキル

#### hidekingerz:single-agent-loop-setup

自律コーディングループ（closed single-agent loop）を任意のリポジトリにセットアップするスキル。

- **何をするか**: ハードニング済み `run.sh`（堅牢な停止検出・サーキットブレーカ・保護ブランチガード）と
  VISION/ARCHITECTURE/RULES/MEMORY/LOOP_PROMPT 雛形を配置し、実 DoD に一致した VERIFY ゲートを設計する
- **Docker 隔離実行**: リポジトリだけをマウントする使い捨てコンテナ、egress allowlist（squid・fail-closed）、
  Playwright ブラウザ入りイメージでの MCP 実行時検証（seccomp プロファイル同梱）まで対応
- **使いどころ**: 無人・隔離・毎周フレッシュ文脈 + MEMORY 引き継ぎが必要な長丁場
  （移行・大規模リファクタ等）。対話中の小タスクは組み込みの `/goal`、定期実行は `/loop`/`/schedule` へ
- **トリガー例**: 「ループをセットアップして」「自律ループを作りたい」「このリポジトリで自走エージェントを回したい」

テンプレートは egress 制限・MCP 検証・maker/checker 分離・長期収束を含む実ループで検証済み。
設計の背景と検証結果は [loop-arch-evaluation の検証レポート](https://github.com/hidekingerz/loop-arch-evaluation/blob/main/docs/verification-report.md) を参照。

#### hidekingerz:graphify

任意のフォルダ（コード・ドキュメント・論文・画像）をナレッジグラフに変換する。
コミュニティ検出・正直な監査証跡つきで、インタラクティブ HTML / GraphRAG 用 JSON /
平文の GRAPH_REPORT.md の3形式を出力。トリガー: `/graphify [path]`

#### hidekingerz:commit-push

作業中の変更をコミットしてリモートへ push するスラッシュコマンド。
差分・既存コミットスタイルの確認 → メッセージ生成 → commit → push まで。

#### hidekingerz:obsidian-handwritten-note

手帳・ノートに手書きしたメモの写真を Obsidian 用 Markdown（デイリーノート /
アイデアノート）へ整形するスラッシュコマンド。画像を渡して「Obsidian に変換して」で発動。

### サブエージェント

- **tech-doc-writer** — README・API ドキュメント・アーキテクチャ文書・セットアップガイド等の
  技術文書を作成する。「README が欲しい」「この API をドキュメント化して」で自動委任される
- **test-writer** — 新規/既存コードのユニット・インテグレーションテストを作成する。
  「テストを書いて」「カバレッジを改善したい」で自動委任される
