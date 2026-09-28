---
status: active
updated: 2026-09-28
---

# 現在の状態

## プロジェクト概要

このリポジトリは、主に日本語の学習ノートを Docsify で閲覧する静的サイトである。`docs/` には 341 個の Markdown ファイル（2026-08-28 調査時点）があり、ルートの Study Notes と、`docs/training/` を入口にする研修資料サイトがある。アプリケーションサーバー、データベース、API はリポジトリ内に存在しない。

## 実装済み

- Docsify による Markdown 表示と、レスポンシブな閲覧 UI。
- Obsidian 形式 Wiki リンクの解決。
- 記事タイトル検索、目次、履歴移動、テーマ、サイドバー調整、コードコピーなどの閲覧支援。
- localStorage を使った記事の完了状態・学習時間・チェックリスト、および JSON バックアップ／復元。
- 重複見出しに一意な ID を付ける Docsify プラグイン。
- ルートサイトのクライアント側パスワード画面と、パスワード画面を持たない研修サイト。
- Markdown から Wiki リンク索引と安定した記事 ID マスターを生成する Python スクリプト。
- パスワード画面と見出し ID に対する Node.js の単体テスト。

## 現在の運用

- 今後の開発先 GitHub リポジトリは `maruyamamasaya/studyApp`。ローカルでは新リポジトリを `origin`、従来の `maruyamamasaya/study` を参照用の `legacy` remote として保持する。新リポジトリは旧履歴を含まない bootstrap commit から開始する。
- 新リポジトリの初期 bootstrap には既存 `docs/**/*.md` の学習ノートと、その内容から生成された `_article-master.json` / `_note-index.json` を含めない。旧履歴も持ち込まず、ID migration の検証後に別フェーズで取り込む。
- Scratch & Build の Phase 0 調査と設計は完了。現行機能は [`CURRENT_FEATURES.md`](CURRENT_FEATURES.md)、新データモデルは [`DATA_MODEL.md`](DATA_MODEL.md)、段階移行は [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md) を基準にする。新実装は Astro の静的生成を採用し、既存 Docsify は cutover まで legacy として維持する。
- ノート同期手順は [`docs/md更新用コマンド.md`](docs/md更新用コマンド.md) にあり、外部ディレクトリから Markdown を `docs/` に rsync して索引を再生成する。
- Git 履歴では記事同期が `Sync notes` コミットとして継続している。
- デプロイ先を明記した CI/CD 設定はリポジトリにない。`docs/.nojekyll` と静的構成は GitHub Pages と整合するが、実際の公開設定はリポジトリだけでは確認できない。

## 既知の制約・未解決事項

- `docs/password-gate.js` のパスワードは配信される JavaScript に平文で含まれる。これは閲覧 UI の抑止にすぎず、機密情報を保護する認証ではない。
- npm/package manifest、lint、typecheck、バンドル、依存関係固定、CI は存在しない。Docsify は実行時に jsDelivr CDN から読み込むため、オフラインでは完全に動作しない。
- ブラウザー UI 全体、Wiki リンク変換、reader tools、索引生成に対する自動テストは限定的または存在しない。
- 外部ノートの正本の場所・バックアップ方針、GitHub Pages の設定、対象ブラウザー、公開 URL、運用責任者はリポジトリから確認できない。
- `docs/臨時フォルダ/`、`docs/保管用・未リンク/` や名前に「無題のファイル」を含む記事は整理候補に見えるが、独立した価値と外部正本が不明なため廃止候補とは確定していない。

## 現在の優先事項・次のアクション候補

次の作業は [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md) の Phase 1 である。

1. 代表 note 5–10件だけを対象に Frontmatter parser、schema、static route の vertical slice を作る。
2. title fallback、duplicate ID、Wiki Link、task list、重複 heading の domain test を先に作る。
3. 全343記事の rename / Frontmatter 追加は、legacy UUID 対応 manifest と generator の冪等性を確認するまで実施しない。
4. 新リポジトリにはまだない package / build / CI を Phase 1 の vertical slice で追加する。
5. cutover 前に公開 URL、本物のアクセス制御要否、Obsidian 正本 location を確定する。

## 詳細への入口

- 構成とデータフロー: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- 現行機能と互換性: [`CURRENT_FEATURES.md`](CURRENT_FEATURES.md)
- 新データモデル: [`DATA_MODEL.md`](DATA_MODEL.md)
- Scratch & Build 計画: [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md)
- 確認できた重要判断: [`decisions/ADR-001-static-docsify-and-generated-indexes.md`](decisions/ADR-001-static-docsify-and-generated-indexes.md)
- 新アーキテクチャ判断: [`decisions/ADR-002-astro-static-study-app.md`](decisions/ADR-002-astro-static-study-app.md)
- 今回の調査記録: [`sessions/2026-08-28-knowledge-bootstrap.md`](sessions/2026-08-28-knowledge-bootstrap.md)
