#!/bin/bash
set -euo pipefail

A="../tar1090_972"
FILES=(default html/config.js html/script.js)

cd "$(dirname "$0")"   # Bのルートで実行

# mainにいて、未コミットの変更がないことを確認
if [ "$(git branch --show-current)" != "main" ]; then
  echo "mainブランチで実行してください"; exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "未コミットの変更があります。先にコミットかstashしてください"; exit 1
fi

# Aを最新化
git -C "$A" pull --ff-only

base=$(tr -d '[:space:]' < .upstream-sha)
head=$(git -C "$A" rev-parse HEAD)

if [ "$base" = "$head" ]; then
  echo "変更なし"
  exit 0
fi

tmp=$(mktemp -d)
conflict=0
for f in "${FILES[@]}"; do
  # このファイルがbase→headで変わっていなければ飛ばす
  if [ -z "$(git -C "$A" diff --name-only "$base" "$head" -- "$f")" ]; then
    continue
  fi
  git -C "$A" show "$base:$f" > "$tmp/base"
  git -C "$A" show "$head:$f" > "$tmp/theirs"
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
  echo "競合マーカー(<<<<<<<)を直してから、次を実行してください:"
  echo "  git add -A && git commit -m 'Sync from upstream (${head:0:7})' && git push"
  echo "(やめる場合は git restore . で元に戻せます)"
else
  git add -A
  git commit -m "Sync from upstream (${head:0:7})"
  echo "ローカルにコミット済み(${head:0:7})。確認後に git push してください"
fi

echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"
echo ""
echo "　以下のコマンドで差分を確認可能（-d以降の引数がWinMergeの確認画面の左と右に配される）"
echo "　　○modforkojに何が入ったか(フォルダ単位でWinMergeが開く)"
echo "　　　　　git difftool -d HEAD~1 HEAD"
echo ""
echo "　　○tar1090_972の何が変わったか(取り込み前のSHAを取り出して比較)"
echo "　　　　　base=$(git show HEAD~1:.upstream-sha)"
echo "　　　　　git -C ../tar1090_972 difftool -d $base HEAD -- default html/config.js html/script.js"
echo ""
echo "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★"

# conflict 変数の値（0 または 1）をそのまま終了ステータスとして返す
exit "$conflict"
