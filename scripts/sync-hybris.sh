#!/usr/bin/env bash
# 保守リポジトリ(hybris)の変更を hybris-sync ブランチへ取り込む。
#   - hybris-sync には subtree pull と取り込み記録しか載せない(移行の作業はしない)
#   - main への反映は hybris-sync -> main の PR でマージする
# usage: scripts/sync-hybris.sh [保守側のブランチ]   (既定: main)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
P=core-customize/hybris SYNC=hybris-sync TARGET=main REMOTE=maint
MBR=${1:-main}

git remote get-url $REMOTE >/dev/null 2>&1 || { echo "remote '$REMOTE' がない: git remote add $REMOTE <保守リポジトリの URL>"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "未コミットの変更がある。片付けてから実行する"; exit 1; }

git fetch -q $REMOTE "$MBR"
git fetch -q origin 2>/dev/null || true
NEW=$(git rev-parse "$REMOTE/$MBR")
git switch -q $SYNC
if git rev-parse -q --verify origin/$SYNC >/dev/null; then git merge -q --ff-only origin/$SYNC; fi
if git rev-parse -q --verify origin/$TARGET >/dev/null; then MAIN=origin/$TARGET; else MAIN=$TARGET; fi

BASE=$(git merge-base HEAD "$NEW")
if [ "$BASE" = "$NEW" ]; then echo "取り込む変更なし(保守 ${NEW:0:7} は取り込み済み)"; exit 0; fi

# 移行側が main で書き換えている保守のファイル(main が最後に取り込んだ保守の版との差分)
MAIN_BASE=$(git merge-base "$MAIN" "$NEW")
MIG_EDITED=$(git diff --name-only --diff-filter=M "$MAIN_BASE^{tree}" "$MAIN:$P")

classify() {
  case $1 in
    *.jsp|*.tag|*/web/src/*|*/web/webroot/*) echo "移植|Angular 側へ移植する(JSP/タグ/Controller)";;
    *items.xml|*-beans.xml)                   echo "OCC|OCC で返す項目・WsDTO・fieldSetLevelMapping を確認する";;
    config/localextensions.xml)               echo "manifest|core-customize/manifest.json の extensions に反映する";;
    config/*)                                 echo "設定|CCv2 の環境プロパティと js-storefront の設定を確認する";;
    *)                                        echo "そのまま|作業なし(Facade/Service などはそのまま使う)";;
  esac
}

mkdir -p sync-ledger
LEDGER=sync-ledger/$(date +%Y%m%d)-${NEW:0:7}.md
{
  echo "# 取り込み記録: 保守 ${BASE:0:7}..${NEW:0:7}"
  echo
  echo "## 保守のコミット"
  echo
  git log --no-merges --format='- `%h` %s (%an, %ad)' --date=short "$BASE..$NEW"
  echo
  echo "## ファイルごとの作業"
  echo
  echo "| 確認 | 区分 | 変更 | ファイル(保守側のパス) | やること | 移行側も変更 |"
  echo "|---|---|---|---|---|---|"
  git diff --name-status --no-renames "$BASE" "$NEW" | while IFS=$'\t' read -r st f; do
    IFS='|' read -r kind todo < <(classify "$f")
    both=""; grep -qxF "$f" <<<"$MIG_EDITED" && both="**衝突候補**"
    echo "| [ ] | $kind | $st | \`$f\` | $todo | $both |"
  done
} > "$LEDGER"

git subtree pull -q --prefix=$P $REMOTE "$MBR" -m "sync: hybris ${NEW:0:7}" >/dev/null
git add "$LEDGER"
git commit -q -m "sync-ledger: hybris ${BASE:0:7}..${NEW:0:7}"

echo "取り込み完了: $SYNC <- 保守 ${NEW:0:7}"
echo "記録: $LEDGER"
echo
if CONFLICTS=$(git merge-tree --write-tree --name-only "$MAIN" $SYNC 2>/dev/null); then
  echo "$MAIN へのマージ: 衝突なし"
else
  echo "$MAIN へのマージ: 衝突あり(docs/merge-conflict.md の手順で解決する)"
  echo "$CONFLICTS" | sed -n '2,/^$/p' | sed '/^$/d; s/^/  /'
fi
echo
echo "次: git push origin $SYNC"
echo "    gh pr create --base $TARGET --head $SYNC --title \"sync: hybris ${NEW:0:7}\" --body-file $LEDGER"
