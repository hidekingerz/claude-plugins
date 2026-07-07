# ARCHITECTURE — 技術スタックとフォルダ構成

> エージェントが DISCOVER を高速化するためのプロジェクト知識。毎周ゼロから推測させない。
> ※ ループの作業ディレクトリ（cwd）は**リポジトリルート**。ループ用ドキュメントは `loop/` 配下。

## スタック

- 言語 / ランタイム: {{例: TypeScript / Node.js 20}}
- フレームワーク: {{例: React / なし}}
- テスト: {{例: Vitest}}
- Lint / Format: {{例: Biome / ESLint+Prettier}}
- パッケージマネージャ: {{例: pnpm}}

## 主要ディレクトリ

```
{{例:
src/          アプリ本体
  ...
test/         テスト
}}
```

## 重要な慣習

- {{例: 公開 API は各ディレクトリの mod から re-export する}}
- {{例: テストは対象ファイルと同階層に *.test.* で置く}}
- {{例: 副作用のある処理は注入可能にして単体テスト可能に保つ}}

## ビルド / 実行 / 検証コマンド

- インストール: `{{例: pnpm install}}`
- VERIFY（毎周の品質ゲート＝速い静的検査）: `{{例: cd app && pnpm lint && pnpm typecheck && pnpm test}}`
- 完了ゲートの追加項目（重い・完了判定のみ）: `{{例: pnpm run smoke（ヘッドレス起動して実行時エラー検知）}}`
- 起動: `{{例: pnpm dev}}`

## MCP による実行時検証（フロント/GUI。エージェントが完了ゲートで実施。bash の VERIFY_CMD では不可）

> Docker 隔離では `Dockerfile.frontend` を使い、リポジトリルートに `.mcp.json` を置く（SKILL.md 参照）。
> ブラウザはコンテナ内で localhost の dev/preview サーバへアクセスする（compose の NO_PROXY=localhost で
> プロキシを迂回）。headless なので**エージェントが dev サーバの起動・待機・停止まで面倒を見る**。

- dev サーバ起動→待機→検証→停止の例（Vite）:
  ```
  {{例:
  (cd app && npm run preview -- --port 4173 --strictPort &)   # バックグラウンド起動
  npx wait-on -t 60000 http://localhost:4173                   # 起動待ち
  # → MCP: Playwright で browser_navigate http://localhost:4173 → browser_console_messages で
  #        コンソールエラー無し・主要要素の存在を確認（chrome-devtools MCP も可）
  pkill -f "vite preview" || true                              # 検証後に停止
  }}
  ```
- 使う MCP: `{{例: Playwright MCP（browser_navigate / browser_console_messages / browser_click）を主に、
  必要なら chrome-devtools MCP。両者ともコンテナ内 Chromium を使う}}`

## 移行元 / 参照（あれば・改変しない）

- {{例: legacy/ … 旧実装。挙動の正解として参照のみ}}
