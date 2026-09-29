# Reader検索・フィルター

## 調査

- `generated/search-index.json`がtitle、tags、aliases、type、本文textを既に持つことを確認した。
- 一覧はAstroの静的HTMLで、追加のAPIや検索サービスを必要としない構成を維持した。

## 実装

- ホームと研修一覧に、title、tag、本文を対象にした即時検索を追加した。
- Unicode NFKCと小文字化で検索語を正規化し、空白区切りの複数語はAND条件にした。
- ホームに`すべて` / `Study` / `Wiki`のtype filterを追加した。
- 表示件数と0件時のメッセージを追加し、キーボード操作と`aria-pressed`に対応した。
- 既存の1列一覧とテーマを保ち、390px幅では操作欄を折り返すようにした。

## 検証

- `npm run check`を実行し、domain test 20件、生成HTML test 9件、Astro buildが成功した。
- ブラウザーで本文検索、Wiki filter、0件表示を確認した。
- 390px幅で横overflowがなく、検索欄とfilterが記事一覧の上に収まることを確認した。

## 残課題

- 検索結果のURL共有と検索語highlightは未実装。
- navigation、目次、code copy、attachment表示は次のReader拡張で扱う。
- Sitesのソースrepository確認はネットワーク権限が許可されず、今回は公開していない。
