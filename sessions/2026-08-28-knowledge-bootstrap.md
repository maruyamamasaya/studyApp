---
status: completed
updated: 2026-08-28
---

# AI 継続開発ドキュメント基盤の導入

## 調査範囲

- ルート、`docs/`、`tests/` のディレクトリ構成と全ファイル種別。
- 既存 Markdown、README、同期メモ、記事索引、設計・TODO・ROADMAP・AI 指示に相当するファイルの有無。
- `docs/index.html`、`docs/training/index.html`、CSS、4 個のブラウザー JavaScript、`build_note_index.py`、2 個のテスト。
- package/pyproject、DB schema/migration、API 定義、インフラ、CI/CD、`.github/`、`documentation/` の有無。
- 初回から直近までの Git 履歴、主要ファイルの変更履歴、直近 30 件のコミット。

## 分類と統合

- 新規に `AGENTS.md`、`CURRENT.md`、`ARCHITECTURE.md`、`decisions/`、`sessions/` を導入した。同等のリポジトリ運用文書は存在しなかった。
- `docs/md更新用コマンド.md` の同期・索引生成手順を AGENTS と CURRENT から参照し、詳細は元ファイルに残した。
- `docs/training/README.md` は研修コンテンツの目次として独立した価値があるため維持した。
- `docs/作業ログ/` はシステム自体の開発 session ではなく、学習・業務ノートのコンテンツであるため移動・統合しなかった。
- `docs/記事：実務編/AGENTS.mdとは？（初心者向け）.md` と `CLAUDE.md と AGENTS.md の違い.md` は公開記事であり、リポジトリ指示ではないため維持した。
- Git 履歴と現行コードで確認できる静的 Docsify・生成索引の選択を ADR-001 に記録した。理由が確認できない部分は推測しなかった。

## 維持した既存資料

- すべての公開記事: サイトの本体コンテンツであり、新しい運用文書とは役割が異なる。
- `docs/md更新用コマンド.md`: 外部ノート同期の具体的なコマンドとして独立した運用価値がある。
- 生成 JSON: 実行時に使用される成果物であり、CURRENT/ARCHITECTURE の代替ではない。
- `docs/バックアップ・復元.md`: 利用者向け機能説明であり、システム構成書とは役割が異なる。

削除・移動した既存資料はない。

## 不明・確認不能

- README、`.github/`、CI/CD、package manifest、DB/API/infra 定義、既存の AI 指示、明示的な TODO/ROADMAP は存在しなかった。
- リポジトリ外のノート正本、正式な公開 URL と GitHub Pages 設定、対象ブラウザー、運用責任者は確認できなかった。
- 静的 Docsify 構成を選んだ当初の議論と代替案は Git 履歴から復元できなかった。
- 一時・保管フォルダの記事が廃止可能かは判断できなかったため、廃止候補として削除しなかった。

## 検証

- 既存 Node.js テストを実行した。
- 索引生成を実行したところ、既存ファイル名の Unicode 正規化差（結合文字を含む `にじいろ保育園.md`）によって記事 ID が再発行される差分を検出した。今回の目的外であり保存済み学習記録を切断し得るため、生成 JSON の差分は取り込まなかった。
- `git diff --check` と文書内リンク・日付・役割の自己レビューを行った。

## 次回への引き継ぎ

次回は `AGENTS.md` → `CURRENT.md` → `ARCHITECTURE.md` → タスク関連 ADR → 関連コードの順に読む。外部運用に触れるタスクでは、上記の不明事項を担当者へ確認してから仕様として文書化する。索引生成器を変更するタスクでは、Unicode 正規化と既存記事 ID の維持を先に検討する。
