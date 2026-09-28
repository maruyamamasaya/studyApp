# Study App 再構築 Phase 0

## 変更

- 従来の `origin`（`https://github.com/maruyamamasaya/study.git`）を `legacy` に改名した。
- 新しい `origin` を `https://github.com/maruyamamasaya/studyApp.git` に設定した。
- 旧リポジトリを誤って更新しないよう、`main` の旧 upstream 設定を解除した。
- 新リポジトリの初期 bootstrap では既存の学習 Markdown と生成索引を除外し、旧 Git 履歴を持ち込まない方針にした。
- 孤立ブランチから新しい root commit を作成し、`studyApp` の `main` として公開した。
- 現行機能と互換性制約を `CURRENT_FEATURES.md` に記録した。
- Frontmatter、article master v2、学習状態、backup v2、legacy mapping を `DATA_MODEL.md` に定義した。
- Astro static を採用する段階移行、gate、rollback を `MIGRATION_PLAN.md` に定義した。
- 技術選定を `decisions/ADR-002-astro-static-study-app.md` に記録した。

## 調査結果

- Markdown 343件、約2.81 MiB、Frontmatter 0件。
- legacy article UUID 343件はすべて一意。
- Wiki Link 361箇所、同名 filename stem 4組。
- checklist 769項目 / 14ファイル。
- version 1 backup は progress / checklist の localStorage 文字列を保存する。
- 現行テストは password gate と unique heading ID の2本。
- index 再生成で `にじいろ保育園.md` の NFC / NFD path 差により UUID が再発行され得ることを確認した。生成差分は採用せず、移行計画へ normalization 検証を追加した。

## 検証

- `git remote -v`
- `git status --short --branch`
- `node tests/password-gate.test.js`
- `node tests/unique-heading-ids.test.js`
- bundled Python で `build_note_index.py` を実行し、NFC / NFD による意図しない生成差分を確認して不採用にした
- `git diff --check`
- 新 root commit の tree に `docs/**/*.md` と生成索引が存在しないことを確認
- `git ls-remote origin refs/heads/main` で公開 commit を確認

## 残課題

- Phase 1 で representative note の Frontmatter / static route vertical slice を実装する。
- 公開 URL、アクセス制御要否、Obsidian 正本 location は cutover 前に確定する。
