# claude-plugins

claude 用スキル置き場（Claude Code plugin marketplace）。

## 導入方法

Claude Code のセッション内で:

```
/plugin marketplace add hidekingerz/claude-plugins
/plugin install single-agent-loop@hidekingerz     # 必要なものだけ選んでインストール
/plugin install graphify@hidekingerz
/plugin install commit-push@hidekingerz
/plugin install obsidian-handwritten-note@hidekingerz
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
    "single-agent-loop@hidekingerz": true
  }
}
```

## 収録プラグイン

### single-agent-loop

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

### graphify

任意のフォルダ（コード・ドキュメント・論文・画像）をナレッジグラフに変換する。
コミュニティ検出・正直な監査証跡つきで、インタラクティブ HTML / GraphRAG 用 JSON /
平文の GRAPH_REPORT.md の3形式を出力。トリガー: `/graphify [path]`

### commit-push

作業中の変更をコミットしてリモートへ push するスラッシュコマンド。
差分・既存コミットスタイルの確認 → メッセージ生成 → commit → push まで。

### obsidian-handwritten-note

手帳・ノートに手書きしたメモの写真を Obsidian 用 Markdown（デイリーノート /
アイデアノート）へ整形するスラッシュコマンド。画像を渡して「Obsidian に変換して」で発動。

### dev-agents

開発補助のサブエージェント集（スキルではなくエージェント定義）:

- **tech-doc-writer** — README・API ドキュメント・アーキテクチャ文書・セットアップガイド等の
  技術文書を作成する。「README が欲しい」「この API をドキュメント化して」で自動委任される
- **test-writer** — 新規/既存コードのユニット・インテグレーションテストを作成する。
  「テストを書いて」「カバレッジを改善したい」で自動委任される
