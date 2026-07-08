# VISION — このループのゴール

> エージェントは毎周これを読み、「完了の定義（DoD）」を満たしたかで停止を判断する。
> 全項目が検証可能でグリーンになるまで `LOOP_DONE` を出力しない。曖昧だとループは終わらない。

## ゴール（1〜2文）

この `claude-plugins` リポジトリの **open GitHub issue のうち `auto-fix` ラベルが付いたもの**を、
1周につき1件ずつ自律的に解消（修正 → VERIFY → コミット → feature ブランチへ push → issue にコメント）し、
処理可能な issue が無くなるまで反復する。**マージ（PR 化含む）は人間が行う。**

## このループの DoD の性質（動的キュー）

このループの「完了の定義」は固定リストではなく、**GitHub 上の open issue キュー**で決まる。
毎周 DISCOVER で `gh issue list` を叩き、下記の「対象 issue」から1件を選んで解消する。

### 対象 issue（1周で1件だけ選ぶ）

```
gh issue list --repo hidekingerz/claude-plugins --state open --label auto-fix --json number,title,labels
```

- `auto-fix` ラベルが付いていること（オプトイン。無差別自動修正を避けるためのゲート）。
- `loop-wip`（別周が着手中）と `loop-needs-human`（人間待ち）は**選ばない**。
- 複数あれば issue 番号の小さい順（古い順）に1件。

### 1件の issue を「解消済み」とみなす条件（per-issue DoD）

- [ ] issue 本文が要求する具体的な変更が実装されている（issue の受け入れ条件を満たす）。
- [ ] 毎周の VERIFY（`loop/verify.sh`）が緑（JSON 妥当・shell 構文妥当・frontmatter 存在）。
- [ ] 変更が**1コミット**にまとまり、feature ブランチに**コミット＋ push** されている。
- [ ] issue に「修正内容の要約・コミット参照・ブランチ名」をコメント済み、`auto-fix` を外し
      解決系ラベル（後述の運用）へ更新、または `loop-needs-human` を付与している。

## 完了ゲート（LOOP_DONE を出してよい条件）

次がすべて満たされたときのみ、最後に独立行で `LOOP_DONE` を出す:

- [ ] `gh issue list --state open --label auto-fix`（`loop-wip`/`loop-needs-human` を除く）が**空**。
      = 着手可能な issue がもう無い。
- [ ] このループが push したブランチで `loop/verify.sh` が緑。
- [ ] 途中で検証不能・判断保留にした issue は `loop-needs-human` を付けて Open に記録済み
      （放置ではなくエスカレーションされている）。

> 「着手可能な issue が残っている」限り `LOOP_DONE` を出さない。逆に、残りが全部
> `loop-needs-human` なら（人間待ちで前進不能なので）`LOOP_DONE` を出して停止してよい。

## スコープ外（やらないこと）

- **PR の自動作成・自動マージはしない。** push まで。PR 化とマージは人間。
- `auto-fix` ラベルの付いていない issue には触らない。
- issue の受け入れ条件を超えた無関係リファクタ・大規模変更をしない（1周=1 issue=最小変更）。
- `loop/` 配下（ループ設定）の書き換え（`loop/MEMORY.md` への追記を除く）。
- 秘密情報・認証情報の変更やコミットへの混入。

## 進行上の注意

- 「VERIFY 緑」＝「issue 解決」ではない。**issue の要求そのものが満たされたか**を客観判定する
  （このリポジトリはランタイムが無いので、判定は issue 本文の受け入れ条件と静的ゲートで行う）。
- 受け入れ条件が曖昧・破壊的・仕様判断を要する issue は、**自動修正せず** `loop-needs-human` を付け、
  Open に理由を残して次へ進む（節目で人間が判断）。
- ドキュメント/スクリプト変更は静的ゲートでは意味的正しさまでは担保できない。マージ前に人間が
  `/code-review` 等でレビューする前提（maker/checker 分離）。
