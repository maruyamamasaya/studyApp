# Phase 1 記事リーダー

## 調査

- `DATA_MODEL.md`、`MIGRATION_PLAN.md`、ADR-002 / ADR-003 と現行コードを確認した。
- 旧公開リポジトリ `maruyamamasaya/study` の main `c072fe8...` を一時領域へ shallow clone し、代表記事だけを選定した。
- legacy 記事5件の UUID / path を `_article-master.json` と照合した。初回追加時刻は shallow clone で検証できないため、Phase 1 は移行時刻を created fallback とし、全件移行前の再検証を残した。

## 実装

- `content/notes/` に legacy 本文5件と Phase 1 fixture 2件を追加した。旧 `docs/` は変更していない。
- Astro 7 の static build、Frontmatter schema、domain validator、generated indexes を追加した。
- ホーム、研修一覧、`/articles/:id/` の静的 route とレスポンシブな記事画面を追加した。
- Wiki Link の alias / heading 解決、曖昧・未解決保留、raw HTML のコード表示を実装した。
- 正確な記事追加・公開手順を `CONTENT_AUTHORING.md` に記録した。

## 検証

- `npm run check`: domain 7件、生成物4件、Astro 9 route の生成に成功。
- 既存の `password-gate.test.js` と `unique-heading-ids.test.js` も成功した。package を ESM 固定せず CommonJS test との互換性を維持した。
- bundled Python で `build_note_index.py` を実行すると legacy Markdown 0件の空索引になることを確認し、ユーザー指定どおり `docs/` にその生成差分を残さなかった。
- ブラウザーでホーム、記事直接 URL、reload、Wiki Link、raw HTML 非実行、モバイル1列、横 overflow なし、console error なしを確認した。
- 既存 Docsify test、`python3 build_note_index.py` の差分、`git diff --check` は最終確認で実行する。

## 残課題

- 全343記事の migration manifest、ID / created 根拠、曖昧 Wiki Link の人手解決は Phase 2 以降。
- 検索 UI、学習状態 adapter、legacy localStorage / backup 移行は未実装。
- npm audit の moderate 1件は依存グラフの確認を残す。強制 update は行っていない。
