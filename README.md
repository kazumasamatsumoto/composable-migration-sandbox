# composable-migration-sandbox

hybris(アクセラレータ)の保守リポジトリの変更を、Composable Storefront の移行リポジトリへ
**取り込み用ブランチ経由で** マージしていく運用を試すための検証用リポジトリです。
対になる保守側は [hybris-maintenance-sandbox](https://github.com/kazumasamatsumoto/hybris-maintenance-sandbox) です。
中身はダミーで、SAP のコードは含みません。

## 2 つのリポジトリ

| | 保守 `hybris-maintenance-sandbox` | 移行 `composable-migration-sandbox`(ここ) |
|---|---|---|
| 構成 | `bin/` `config/` が直下 | CCv2 の形: `core-customize/hybris/`(= 保守の中身)、`core-customize/manifest.json`、`js-storefront/` |
| 持ち主 | 保守チーム | 移行チーム |
| 運用 | 普段どおり `main` にコミット。移行のために何も変えない | 下のブランチ運用 |

保守の `bin/custom/shop/...` は、こちらでは `core-customize/hybris/bin/custom/shop/...` にあります。
このパスのずれは `git subtree`(`--squash` なし)で移行側だけが吸収します。

## ブランチ

```
保守 main ──●───────●───────●─────────────
             \       \       \
hybris-sync ──●───────●───────●──── (subtree pull と取り込み記録だけ)
               \       \       \
main ──●──●──●──●──●──●──●──●──●── (移行の作業。hybris-sync を PR でマージ)
```

| ブランチ | 載せるもの | 載せないもの |
|---|---|---|
| `hybris-sync` | `git subtree pull` の結果と `sync-ledger/*.md`(取り込み記録) | 移行の作業。`main` からのマージ |
| `main` | 移行の作業、`hybris-sync` のマージ | — |

`hybris-sync` に移行の作業を混ぜないので、`subtree pull` 自体は必ず衝突なしで終わります。
衝突が起きるのは `hybris-sync` → `main` のマージだけで、そこで移行チームが解決します。

## 取り込みの手順

```sh
git clone https://github.com/kazumasamatsumoto/composable-migration-sandbox.git
cd composable-migration-sandbox
git remote add maint https://github.com/kazumasamatsumoto/hybris-maintenance-sandbox.git
git branch hybris-sync origin/hybris-sync

scripts/sync-hybris.sh                 # hybris-sync へ取り込み、記録を作り、main と衝突するか先に表示
git push origin hybris-sync
gh pr create --base main --head hybris-sync --title "sync: hybris <sha>" --body-file sync-ledger/<記録>.md
```

PR の本文には、`sync-ledger/` の記録が入ります。
記録では、保守が変えたファイルを次のように分けます。

| 区分 | 対象 | やること |
|---|---|---|
| 移植 | `*.jsp` `*.tag` `web/src` `web/webroot` | Angular 側(`js-storefront/`)へ同じ振る舞いを移す。取り込んだ JSP はデプロイでは使われない |
| OCC | `*items.xml` `*-beans.xml` | OCC で返す項目(WsDTO、`fieldSetLevelMapping`)を確認する |
| manifest | `config/localextensions.xml` | `core-customize/manifest.json` の `extensions` に反映する |
| 設定 | その他の `config/*` | CCv2 の環境プロパティ、フロントの設定を確認する |
| そのまま | それ以外(Facade / Service など) | 作業なし |

移行側も `main` で書き換えている保守のファイルには「衝突候補」の印が付きます。

衝突したときの手順は [docs/merge-conflict.md](docs/merge-conflict.md) にあります。

## 移行側の修正を保守へ返す

`core-customize/hybris/` の下で保守のファイルを直したら、保守のレイアウトのパッチにして渡します。

```sh
scripts/upstream-patch.sh <commit>...    # upstream-patches/ に出力(パスは bin/... から始まる)
# 保守側で
git am -3 /path/to/upstream-patches/*.patch
```

保守がそれをリリースしたあとの取り込みでは、同じ変更が戻ってくるので、衝突しません。

## 一通りを手元で試す

```sh
scripts/verify-local.sh
```

GitHub の 2 リポジトリを一時ディレクトリへ bare で複製し、そこへ push しながら次を試します。
本物のリポジトリには push しません。

| | シナリオ |
|---|---|
| S1 | 保守が JSP・設定・拡張一覧を変更 → `hybris-sync` に取り込み → 衝突なしで `main` へマージ |
| S2 | 同じ行を両方が変更 → 記録と事前チェックで衝突が分かる → 作業ブランチで解決 → `hybris-sync` は汚れない |
| S3 | 移行の修正をパッチで保守へ返す → 保守のリリースを取り込んでも衝突しない |
| S4 | 保守に変更がないときは何もしない |
| S5 | 保守リポジトリの直下の構成は最後まで変わらない |

## 置いてあるもの

| パス | 中身 |
|---|---|
| `core-customize/hybris/` | 保守リポジトリの中身(subtree) |
| `core-customize/hybris/bin/custom/shopocc/` | 移行だけが持つ拡張。`warrantyMonths` を OCC の応答に載せる |
| `core-customize/manifest.json` | CCv2 のビルド定義(検証用の一般形。CCv2 でのビルドはしていない) |
| `js-storefront/` | フロントの置き場所。JSP から移した例 `warranty.component.ts` だけを置いている |
| `scripts/` | `sync-hybris.sh` / `upstream-patch.sh` / `verify-local.sh` |
| `sync-ledger/` | 取り込みのたびの記録(`hybris-sync` で作られる) |

## 解説

この運用の考え方は、次の 26 章にあります。

[spartacus-architecture-notes 26 章](https://github.com/kazumasamatsumoto/spartacus-architecture-notes/blob/main/docs/26-repository-strategy-parallel-maintenance.md) の方式 A
