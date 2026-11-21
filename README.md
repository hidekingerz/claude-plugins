# claude-plugins

claude 用スキル置き場（Claude Code plugin marketplace）。
全スキル・エージェントを単一プラグイン `hidekingerz` に束ねている（vercel プラグインと同じ方式）。
スキルは `hidekingerz:<スキル名>` の名前で利用できる。
別のリポジトリで育てているものは、個別のプラグインとして載せている（[別リポジトリのプラグイン](#別リポジトリのプラグイン)）。

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

#### hidekingerz:mado-show

[herdr](https://herdr.dev) 上で作業しているとき、markdown を agent の隣の
mado report ペインに表示するスキル。plan / spec / report の `.md` を書き終えたら
コミットの有無に関わらず自動で表示し、「mado で見せて」でも発動する。
前提: herdr 0.8+ と [herdr-plugin-mado](https://github.com/hidekingerz/herdr-plugin-mado)
の agent-report-viewer 0.2.0+（`herdr plugin action invoke mado.agent-report-viewer.install-cli` 実行済み）。

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

## 別リポジトリのプラグイン

本体を別のリポジトリで育てているものは、`hidekingerz` プラグインには束ねず、個別のプラグインとして載せている。
ここにあるのは入口だけで、中身はそれぞれのリポジトリから取得される。

### dokumi

AI エージェントが書いたフロントエンドの変更を、PR を作る前に実行して検証するスキル（毒味）。
型・lint・テスト・ビルドの実行、ごまかしの検出、要件との突き合わせ、ミューテーションテストによるテストの質の実測、
実ブラウザでの動作確認を行い、PASS / FIX / ESCALATE の判定と、人向け・エージェント向けのレポートを出す。

```
/plugin install dokumi@hidekingerz
```

- スキル名は `dokumi:dokumi`。「PR 前に dokumi で検証して」で発動する。フロントエンドの実装を終えたときにも自動で呼ばれる
- 本体: [hidekingerz/dokumi](https://github.com/hidekingerz/dokumi)（MIT）。
  使い方は [docs/usage.md](https://github.com/hidekingerz/dokumi/blob/main/docs/usage.md)、
  判定基準は [docs/criteria.md](https://github.com/hidekingerz/dokumi/blob/main/docs/criteria.md)
- バージョンは固定していない。dokumi の `main` が進むと、`/plugin marketplace update hidekingerz` で新しい内容が入る
- 必須: Node.js 18 以上と git。テストの質の実測は Node.js 24 以上と Vitest 5、実ブラウザ検証は Playwright が要る
  （無い場合は、その段階が代替手順か「未実施」になる）
- プロジェクトで自動有効化するときは、`enabledPlugins` に `"dokumi@hidekingerz": true` を足す
