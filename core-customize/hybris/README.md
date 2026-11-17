# hybris-maintenance-sandbox

保守チームの SAP Commerce(アクセラレータ)リポジトリを模した検証用リポジトリです。
**本物の SAP のコードは含みません**。ファイルの置き場所と変更の流れだけを再現したダミーです。

- `bin/` と `config/` がリポジトリ直下にある(保守チームはこの構成を変えない)
- 運用は普段どおり `main` へコミットするだけ。移行チームの都合で何かを変えることはない

移行側(Composable Storefront)がこのリポジトリをどう取り込むかは、
[composable-migration-sandbox](https://github.com/kazumasamatsumoto/composable-migration-sandbox) を参照してください。

| パス | 役割 |
|---|---|
| `config/localextensions.xml` | 使う拡張の一覧 |
| `config/local.properties` | 設定値 |
| `bin/custom/shop/shopcore` | 型定義(items.xml) |
| `bin/custom/shop/shopfacades` | Facade / Populator(移行後も使う) |
| `bin/custom/shop/shopstorefront` | JSP と Controller(移行後は Angular に置き換わる) |
