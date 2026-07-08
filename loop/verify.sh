#!/usr/bin/env bash
#
# verify.sh — claude-plugins リポジトリの静的品質ゲート（毎周の VERIFY）
#
# このリポジトリはビルド/ランタイムを持たない（Markdown + JSON + shell の集合）ため、
# 速い静的検査で「構造が壊れていないこと」を担保する:
#   1. 全 JSON が構文妥当（jq empty）
#   2. 全 *.sh が構文妥当（bash -n）
#   3. 全 SKILL.md / agents/*.md に frontmatter（name / description）が存在
#
# 意味的な正しさ（issue の受け入れ条件を満たしたか）はこのゲートでは担保しない。
# それはエージェントの VERIFY 段の客観判定と、マージ前の人間レビューが担う（loop/VISION.md 参照）。
#
# 使い方: リポジトリルートで `./loop/verify.sh`（run.sh からは VERIFY_CMD="./loop/verify.sh"）

set -uo pipefail

# リポジトリルートへ移動（このスクリプトは loop/ 配下）
cd "$(dirname "$0")/.."

fail=0
err() { echo "  ✗ $1" >&2; fail=1; }

# 検索対象から除外するパス
PRUNE=( -path './.git' -o -path './loop' -o -path './node_modules' )

echo "== VERIFY: JSON 構文（jq empty） =="
if ! command -v jq >/dev/null 2>&1; then
  err "jq が見つかりません（JSON 検証に必須）"
else
  while IFS= read -r f; do
    if jq empty "$f" >/dev/null 2>&1; then
      echo "  ✓ $f"
    else
      err "JSON 構文エラー: $f"
      jq empty "$f" 2>&1 | sed 's/^/      /' >&2 || true
    fi
  done < <(find . \( "${PRUNE[@]}" \) -prune -o -name '*.json' -type f -print | sort)
fi

echo "== VERIFY: shell 構文（bash -n） =="
while IFS= read -r f; do
  # loop/ 配下（ループ設定スクリプト）は検査対象外にしない — 誤って壊すのも困るので検査する。
  if bash -n "$f" 2>/dev/null; then
    echo "  ✓ $f"
  else
    err "shell 構文エラー: $f"
    bash -n "$f" 2>&1 | sed 's/^/      /' >&2 || true
  fi
done < <(find . \( -path './.git' -o -path './node_modules' \) -prune -o -name '*.sh' -type f -print | sort)

echo "== VERIFY: frontmatter（name / description） =="
check_frontmatter() {
  local f="$1"
  # 1行目が --- で始まり、2つ目の --- までの間に name: と description: があること
  if [[ "$(head -n1 "$f")" != '---' ]]; then
    err "frontmatter 開始 '---' が無い: $f"
    return
  fi
  # 先頭の --- から次の --- までを frontmatter ブロックとして抽出
  local block
  block="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$f")"
  if ! grep -qE '^name:' <<<"$block"; then err "frontmatter に name が無い: $f"; return; fi
  if ! grep -qE '^description:' <<<"$block"; then err "frontmatter に description が無い: $f"; return; fi
  echo "  ✓ $f"
}
while IFS= read -r f; do
  check_frontmatter "$f"
done < <(find plugins -type f \( -name 'SKILL.md' -o -path '*/agents/*.md' \) 2>/dev/null | sort)

echo
if [[ "$fail" -ne 0 ]]; then
  echo "== VERIFY: FAILED ==" >&2
  exit 1
fi
echo "== VERIFY: PASSED =="
