#!/usr/bin/env bash
# 移行側で core-customize/hybris の下を直したコミットを、保守のレイアウト(bin/ config/ が直下)の
# パッチにする。保守側は `git am -3 upstream-patches/*.patch` で取り込む。
# usage: scripts/upstream-patch.sh <commit>...
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
P=core-customize/hybris OUT=upstream-patches
[ $# -gt 0 ] || { echo "usage: $0 <commit>..."; exit 1; }
rm -rf $OUT; mkdir -p $OUT
n=0
for c in "$@"; do
  outside=$(git diff-tree --no-commit-id --name-only -r "$c" | grep -v "^$P/" || true)
  [ -z "$outside" ] || { echo "注意: $(git log -1 --format=%h "$c") は $P の外も変えている(パッチには含めない):"; echo "$outside" | sed 's/^/  /'; }
  n=$((n+1))
  git format-patch -q -1 "$c" --relative=$P --start-number=$n -o $OUT
done
ls $OUT
echo "保守側で: git am -3 <このディレクトリ>/*.patch"
