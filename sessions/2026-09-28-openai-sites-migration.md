# OpenAI Sites への配信先変更

## 調査

- 現行リポジトリは Phase 0 の bootstrap 状態で、学習記事 Markdown と生成索引はまだ取り込まれていない。
- `docs/` には旧 Docsify の表示資産だけがあり、現在のまま新しい閲覧サイトとして公開するとホーム記事が欠ける。
- ADR-002 の Astro static 方針は hosting から独立しており、OpenAI Sites でも維持できる。

## 実装

- `dist/` に OpenAI Sites 用の独立した静的サイトを追加した。
- 初期版は、記事移行が未完了であることを隠さず、現在の milestone と次の実装を示すページにした。
- `.openai/hosting.json` に Sites の project ID と `dist` の公開設定を保存した。
- hosting の変更を CURRENT、ARCHITECTURE、MIGRATION_PLAN、ADR-003 に反映した。

## 検証

- ローカル HTTP 応答が 200 であることを確認した。
- desktop 1280px と mobile 390px で表示し、横 overflow、空画面、ブラウザー console error がないことを確認した。
- 既存 Node test、JSON 構文、`git diff --check` を実行する。
- OpenAI Sites へ private publish し、deployment status が成功になることを確認する。

## 残課題

- 学習記事本体と既存 localStorage データの移行は `MIGRATION_PLAN.md` の後続 phase で行う。
- 旧 GitHub Pages の停止と URL / custom domain の切替は cutover 条件を満たしてから行う。
