# hybris-sync → main が衝突したとき

`scripts/sync-hybris.sh` が「衝突あり」と表示したとき、または PR が衝突したときの手順です。

**`main` を `hybris-sync` にマージしてはいけません。**
GitHub の「Resolve conflicts」ボタンもこれと同じことをするので、使いません。
`hybris-sync` には、保守から取り込んだものだけを置きます。

```sh
git fetch origin
git switch -c merge/hybris-<sha> origin/main
git merge origin/hybris-sync          # ここで衝突する
# 衝突したファイルで、保守の意図と移行の意図を両方残す形に書き直す
git add <ファイル>
git commit
git push origin merge/hybris-<sha>
gh pr create --base main --head merge/hybris-<sha> --title "sync: hybris <sha>(衝突解決)" --body-file sync-ledger/<記録>.md
```

この PR をマージしたら、`hybris-sync` からの元の PR は閉じます。
中身はもう `main` に入っています。

## 衝突を減らすには

- 保守のファイル(`core-customize/hybris/bin/custom/shop/...`)を移行側で直接直すのは、最小限にする
- 直したら `scripts/upstream-patch.sh` で保守へ返す。保守がリリースすれば、次の取り込みからは衝突しない
- 移行だけのものは、移行だけの拡張(`shopocc` など)に置く
