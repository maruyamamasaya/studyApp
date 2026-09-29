# 5テーマ切替

## 調査

- 新 Study App の Astro layout と global CSS、既存の generated-site test を確認した。
- 参照指定された `maruyamamasaya/living-aurora-ui` のテーマ資料とトークンを確認し、Living Aurora、Blue Cosmos、Pulse Neon の色・面・光の性格を抽出した。
- 旧 Docsify 側には既存の5テーマ切替があるが、新 Study App 側は単一テーマだった。

## 実装

- 共通ヘッダーにネイティブ select のテーマ選択を追加した。
- Standard、Wiki、Living Aurora、Blue Cosmos、Pulse Neon の5テーマをCSSカスタムプロパティで実装した。
- 保存済みテーマをhead内で先に適用して初期描画のちらつきを抑え、選択は `study-app:theme` としてlocalStorageへ保存する。
- reduced motion、モバイル表示、storageを利用できない環境でのfallbackを維持した。

## 検証

- generated-site test に5テーマの選択肢と保存処理の出力検証を追加した。
- 初回の `npm run check` では build とテーマ検証が成功した。全体では、並行中の Obsidian 同期変更による標準相対リンクの既存期待値1件だけが失敗した。
- ブラウザーで5テーマを切り替え、再読込後の選択保持、記事ページへの引継ぎ、390px幅で横overflowなし、console errorなしを確認した。
- `node --test --test-name-pattern="5種類の表示テーマ" tests/generated-site.test.mjs`、legacy Node test 2件、`git diff --check` は成功した。
- 並行して追加された `20260929-133348.md` の同期途中には一時的な schema error が出たが、同期完了後の `npm run build` は12記事・14ページで成功した。

## 残課題

- Obsidian 同期で配置先が変わった fixture の標準相対リンクについて、既存 output test の期待値1件が未解決。テーマの生成・操作には影響しない。
