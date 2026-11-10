#!/bin/bash
set -euo pipefail

A="../tar1090_972"
FILES=(default html/config.js html/script.js)
WINMERGE="/c/Program Files/WinMerge/WinMergeU.exe"

cd "$(dirname "$0")"   # Bのルートで実行

# 引数: [from] [to]  省略時は「前回取り込み位置 → Aの上流の最新」
if [ $# -ge 1 ]; then from="$1"; else from=$(tr -d '[:space:]' < .upstream-sha); fi
if [ $# -ge 2 ]; then to="$2"; else to='@{u}'; fi

tmp=$(mktemp -d)
mkdir -p "$tmp/left" "$tmp/right"
for f in "${FILES[@]}"; do
  mkdir -p "$tmp/left/$(dirname "$f")" "$tmp/right/$(dirname "$f")"
  git -C "$A" show "$from:$f" > "$tmp/left/$f"
  git -C "$A" show "$to:$f"   > "$tmp/right/$f"
done

"$WINMERGE" -e -u "$(cygpath -w "$tmp/left")" "$(cygpath -w "$tmp/right")"
