#!/bin/bash
set -euo pipefail

A="../tar1090_972"
FILES=(default html/config.js html/script.js)

cd "$(dirname "$0")"   # Bのルートで実行

# Aを最新化
git -C "$A" pull --ff-only

base=$(tr -d '[:space:]' < .upstream-sha)
head=$(git -C "$A" rev-parse HEAD)

if [ "$base" = "$head" ]; then
  echo "変更なし"
  exit 0
fi

# 対象ファイルに変更があったか確認
if [ -z "$(git -C "$A" diff --name-only "$base" "$head" -- "${FILES[@]}")" ]; then
  echo "対象ファイルは未変更。SHAだけ更新します"
  printf '%s' "$head" > .upstream-sha
  git add .upstream-sha
  git commit -m "Update upstream sha (${head:0:7})"
  exit 0
fi

git switch -c "sync-${head:0:7}"

tmp=$(mktemp -d)
conflict=0
for f in "${FILES[@]}"; do
  # このファイルがbase→headで変わっていなければ飛ばす
  if [ -z "$(git -C "$A" diff --name-only "$base" "$head" -- "$f")" ]; then
    continue
  fi
  git -C "$A" show "$base:$f" > "$tmp/base"
  git -C "$A" show "$head:$f" > "$tmp/theirs"
  # 競合があると終了コードが1以上になるので、止まらないように受ける
  git merge-file "$f" "$tmp/base" "$tmp/theirs" || {
    rc=$?
    if [ "$rc" -gt 127 ]; then echo "エラー: $f"; exit 1; fi
    conflict=1
    echo "競合: $f"
  }
done
rm -rf "$tmp"

printf '%s' "$head" > .upstream-sha

if [ "$conflict" = 1 ]; then
  echo "競合マーカー(<<<<<<<)を直してから git add -A && git commit してください"
else
  git add -A
  git commit -m "Sync from upstream (${head:0:7})"
  echo "コミット済み。問題なければmainにマージしてpushしてください"
fi
