---
name: mado-show
description: herdr の中で動いているとき（シェルに HERDR_WORKSPACE_ID がある）に、markdown を agent の隣の mado に出したい場面で使う — ユーザーが「mado で見せて」「mado で開いて」と .md の表示を頼んだとき、ランの終了を待たずに今すぐ読ませたい .md があるとき、または git リポジトリの外や gitignore 配下に plan / spec / 設計書 / report を書いたとき。
---

# mado-show

## 概要

herdr プラグイン `mado.agent-report-viewer`（0.3.0 以降）は、agent のランが
終わった時点で、**そのランが触った markdown** を自動で mado に開く。未コミット
でもコミット済みでも対象になるので、リポジトリ内に書いた plan や report は
何もしなくても表示される。

自動では出ないのは次の場合で、そのために明示的に渡すコマンドをプラグインが
用意している。

- このランで触っていないファイル（ユーザーが名指しで頼んだものなど）
- git リポジトリの外、または gitignore 配下のファイル
- ランの終了を待たずに、今すぐ読ませたいファイル

## コマンド

```sh
sh "$(herdr plugin config-dir mado.agent-report-viewer)/show" docs/plan.md
```

- パスは何個でも。カレントディレクトリ基準の相対パスでも絶対パスでも良い。
- このワークスペースの mado report ペインにタブとして開く。report ペインが
  無くても、同じタブで mado が既に動いていればそこに開く。どちらも無ければ
  report ペインを新しく開く。herdr の外や、存在しないパスに対しては何も
  しないので、いつ実行しても安全。
- Bash ツールから普通のコマンドとして実行する。すぐに返ってくる。

`show: No such file or directory` で失敗したら、このマシンにまだシムが
入っていない。`herdr plugin action invoke mado.agent-report-viewer.install-cli`
を一度実行してから再試行する。

## いつ実行するか

| 状況 | すること |
| --- | --- |
| ユーザーが「mado で見せて」「X を mado で開いて」と言った | X に `show` を実行する |
| git リポジトリの外、または gitignore 配下に plan / spec / 設計書 / report を書いた | ターンを終える前にそのファイルに `show` を実行する |
| 長いランの途中で、先に読んでおいてほしい `.md` を書いた | その場で `show` を実行する |
| リポジトリ内の `.md` を書いた・直しただけ | 何もしない。ランが終わるとプラグインが開く |
| `HERDR_WORKSPACE_ID` が無い（herdr の外） | 何もしない。どのみちコマンドも no-op |

## よくある間違い

- **リポジトリ内に書いた `.md` にも毎回 `show` を実行する** — ランが終わると
  プラグインが同じファイルをもう一度開くので、通知が二重に出る。
- **Bash ツールから `mado file.md` を直接実行する** — agent 自身のシェルで
  新しいビューアを起動してしまう。そこには TTY が無いので固まるか、
  agent のペインを乗っ取る。隣の mado に出すには `show` を使う。
- **`herdr plugin action invoke mado.docs-peek.peek`** — これは `docs/`
  ディレクトリのツリーを開くもので、特定のファイルを開く用途ではない。
