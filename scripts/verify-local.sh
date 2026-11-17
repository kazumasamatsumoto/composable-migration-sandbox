#!/usr/bin/env bash
# 2 つのリポジトリの運用を、手元の一時ディレクトリで最初から最後まで試す。
# GitHub の代わりにローカルの bare リポジトリを使うので、本物のリポジトリには push しない。
# usage: scripts/verify-local.sh [作業ディレクトリ]
set -euo pipefail
SELF=$(cd "$(dirname "$0")/.." && pwd)
MAINT_URL=${MAINT_URL:-https://github.com/kazumasamatsumoto/hybris-maintenance-sandbox.git}
MIG_URL=${MIG_URL:-https://github.com/kazumasamatsumoto/composable-migration-sandbox.git}
W=${1:-$(mktemp -d)}; rm -rf "$W"; mkdir -p "$W"; cd "$W"
export GIT_AUTHOR_NAME=verify GIT_AUTHOR_EMAIL=verify@example.com GIT_COMMITTER_NAME=verify GIT_COMMITTER_EMAIL=verify@example.com
P=core-customize/hybris
FACADE=bin/custom/shop/shopfacades/src/com/example/shop/facades/populators/WarrantyPopulator.java
pass=0 fail=0
hr()   { echo; echo "=== $* ==="; }
ok()   { echo "PASS: $*"; pass=$((pass+1)); }
ng()   { echo "FAIL: $*"; fail=$((fail+1)); }
check(){ local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ng "$d"; fi; }
sync() { (cd mig && "$SELF/scripts/sync-hybris.sh" "$@"); }
pure() { (cd mig && ! git merge-base --is-ancestor origin/main hybris-sync); }   # hybris-sync に main の作業が混ざっていない

git clone -q --bare "$MAINT_URL" maint.git
git clone -q --bare "$MIG_URL" mig.git
git clone -q maint.git maint
git clone -q mig.git mig
(cd mig && git branch -q hybris-sync origin/hybris-sync && git remote add maint ../maint.git)

hr "S1 保守がいつもどおりリリースする(JSP・設定・拡張の追加)"
(cd maint
 sed -i.bak 's/CenterLeftContentSlot/CenterLeftContentSlot-v2/' bin/custom/shop/shopstorefront/web/webroot/WEB-INF/views/responsive/pages/cart/cartPage.jsp
 sed -i.bak 's/maxQuantity=99/maxQuantity=50/' config/local.properties
 sed -i.bak 's#<extension name="shopstorefront"/>#<extension name="shopstorefront"/>\n\t\t<extension name="shoppromotion"/>#' config/localextensions.xml
 find . -name '*.bak' -delete
 git commit -qam "M1 cart slot rename, maxQuantity 50, add shoppromotion"; git push -q)
OUT=$(sync); echo "$OUT"
L=$(cd mig && git diff-tree --no-commit-id --name-only -r hybris-sync -- sync-ledger/)
LEDGER=$(cd mig && git show "hybris-sync:$L")
check "記録に JSP が「移植」として載る"          grep -q '| 移植 | M | `bin/custom/shop/shopstorefront/.*cartPage.jsp`' <<<"$LEDGER"
check "記録に localextensions が「manifest」で載る" grep -q '| manifest | M | `config/localextensions.xml`' <<<"$LEDGER"
check "main へのマージは衝突なし"               grep -q '衝突なし' <<<"$OUT"
check "hybris-sync は main の作業を含まない"     pure
(cd mig && git push -q origin hybris-sync && git switch -q main && git merge -q --no-ff hybris-sync -m "Merge PR: sync hybris (S1)" && git push -q origin main)
check "main の core-customize/hybris に保守の変更が入った" grep -q maxQuantity=50 mig/$P/config/local.properties
check "移行だけの拡張 shopocc は残っている"     test -f mig/$P/bin/custom/shopocc/resources/shopocc-spring.xml

hr "S2 同じ行を両方が変える(衝突)"
(cd mig && sed -i.bak 's/target.setWarrantyMonths(source.getWarrantyMonths());/target.setWarrantyMonths(source.getWarrantyMonths() == null ? 0 : source.getWarrantyMonths());/' $P/$FACADE && rm $P/$FACADE.bak \
   && git commit -qam "MIG null-safe warranty for OCC" && git push -q origin main)
(cd maint && sed -i.bak 's/target.setWarrantyMonths(source.getWarrantyMonths());/target.setWarrantyMonths(Integer.valueOf(source.getWarrantyMonths()));/' $FACADE && rm $FACADE.bak \
   && git commit -qam "M2 boxing fix" && git push -q)
OUT=$(sync); echo "$OUT"
L=$(cd mig && git diff-tree --no-commit-id --name-only -r hybris-sync -- sync-ledger/)
check "記録で衝突候補に印が付く"  grep -q 'WarrantyPopulator.java.*衝突候補' <<<"$(cd mig && git show "hybris-sync:$L")"
check "マージ前に衝突が分かる"    grep -q 'WarrantyPopulator.java' <<<"$OUT"
(cd mig && git switch -q -c merge/hybris-s2 origin/main
 git merge -q hybris-sync -m "Merge hybris-sync (S2)" >/dev/null 2>&1 || true
 git checkout -q --ours $P/$FACADE        # 本番ではここで両方の意図を合わせて書く
 git add $P/$FACADE && git commit -q --no-edit
 git switch -q main && git merge -q --ff-only merge/hybris-s2 && git push -q origin main)
check "解決後も hybris-sync は main の作業を含まない" pure
check "解決した内容が main にある" grep -q '== null ? 0' mig/$P/$FACADE

hr "S3 移行側の修正を保守へ返す(format-patch --relative + am -3)"
(cd mig && sed -i.bak 's#<property name="warrantyMonths" type="Integer"/>#<property name="warrantyMonths" type="Integer"/>\n\t\t<property name="warrantyLabel" type="String"/>#' $P/bin/custom/shop/shopfacades/resources/shopfacades-beans.xml \
   && find . -name '*.bak' -delete && git commit -qam "MIG add warrantyLabel to ProductData" && git push -q origin main \
   && "$SELF/scripts/upstream-patch.sh" HEAD)
(cd maint && git pull -q && git am -q -3 ../mig/upstream-patches/*.patch && git push -q)
check "保守側ではパスが bin/ から始まる" grep -q warrantyLabel maint/bin/custom/shop/shopfacades/resources/shopfacades-beans.xml
OUT=$(sync); echo "$OUT"
check "戻ってきた同じ変更はマージで衝突しない" grep -q '衝突なし' <<<"$OUT"
(cd mig && git switch -q main && git merge -q --no-ff hybris-sync -m "Merge PR: sync hybris (S3)" && git push -q origin main)

hr "S4 保守に変更がないとき"
check "「取り込む変更なし」で止まる" grep -q '取り込む変更なし' <<<"$(sync)"

hr "S5 保守リポジトリの構成は変わっていない"
check "保守の直下は bin/ config/ README.md のまま" test "$(cd maint && git ls-tree --name-only HEAD | tr '\n' ' ')" = "README.md bin config "

hr "履歴"
(cd mig && git --no-pager log --graph --format='%h %s' main hybris-sync | head -40)
echo; echo "結果: PASS $pass / FAIL $fail  (作業ディレクトリ: $W)"
[ $fail = 0 ]
