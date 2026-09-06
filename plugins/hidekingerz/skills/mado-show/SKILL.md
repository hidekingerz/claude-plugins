---
name: mado-show
description: herdr の中で動いているとき（シェルに HERDR_WORKSPACE_ID がある）に、markdown を agent の隣の mado report ペインに出したい場面で使う — plan / spec / 設計書 / report の .md を書き終えたとき（コミット済みでも）、またはユーザーが「mado で見せて」「mado で開いて」と .md の表示を頼んだとき。
---

# mado-show

## 概要

herdr プラグイン `mado.agent-report-viewer` は agent のランが生成した
markdown を自動で開くが、対象は**ターン終了時にまだ未コミット**の
ファイルだけ。同じターンでコミットしたレポートや、ターンの途中で
ユーザーが頼んだファイルは、明示的に report ペインへ渡す必要がある。
そのためのコマンドをプラグインが用意している。

## コマンド

```sh
sh "$(herdr plugin config-dir mado.agent-report-viewer)/show" docs/plan.md
```

- パスは何個でも。カレントディレクトリ基準の相対パスでも絶対パスでも良い。
- このワークスペースの mado report ペインにタブとして開く。ペインが
  既にあれば再利用する。herdr の外や、存在しないパスに対しては何も
  しないので、いつ実行しても安全。
- Bash ツールから普通のコマンドとして実行する。すぐに返ってくる。

`show: No such file or directory` で失敗したら、このマシンにまだシムが
入っていない。`herdr plugin action invoke mado.agent-report-viewer.install-cli`
を一度実行してから再試行する。

## いつ実行するか

| 状況 | すること |
| --- | --- |
| plan / spec / 設計書 / report の `.md` を書き終えた | ターンを終える前にそのファイルに `show` を実行する — コミットした場合も同じ |
| ユーザーが「mado で見せて」「X を mado で開いて」と言った | X に `show` を実行する |
| `HERDR_WORKSPACE_ID` が無い（herdr の外） | 何もしない。どのみちコマンドも no-op |

## よくある間違い

- **Bash ツールから `mado file.md` を直接実行する** — agent 自身のシェルで
  新しいビューアを起動してしまう。そこには TTY が無いので固まるか、
  agent のペインを乗っ取る。隣の report ペインに出すには `show` を使う。
- **`herdr plugin action invoke mado.docs-peek.peek`** — これは `docs/`
  ディレクトリのツリーを開くもので、特定のファイルを開く用途ではない。
