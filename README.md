# claude-plugins

claude 用スキル置き場（Claude Code plugin marketplace）。

## 導入方法

Claude Code のセッション内で:

```
/plugin marketplace add hidekingerz/claude-plugins
/plugin install single-agent-loop@hidekingerz
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
