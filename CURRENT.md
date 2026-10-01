---
status: active
updated: 2026-09-29
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
- Scratch & Build の調査と初期実装は完了。現行機能は [`CURRENT_FEATURES.md`](CURRENT_FEATURES.md)、新データモデルは [`DATA_MODEL.md`](DATA_MODEL.md)、今後の作り直しは [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md) を基準にする。新実装は Astro の静的生成を採用し、既存 Docsify は参照用 legacy として維持する。
- ノート同期手順は [`docs/md更新用コマンド.md`](docs/md更新用コマンド.md) にあり、外部ディレクトリから Markdown を `docs/` に rsync して索引を再生成する。
- Git 履歴では記事同期が `Sync notes` コミットとして継続している。
- デプロイ先を明記した CI/CD 設定はリポジトリにない。`docs/.nojekyll` と静的構成は GitHub Pages と整合するが、実際の公開設定はリポジトリだけでは確認できない。
- 新しい公開先は OpenAI Sites とし、`.openai/hosting.json` に Sites の設定、`dist/` に公開対象を置く。新サイトは非公開で開始し、旧 GitHub Pages は cutover 条件を満たすまで rollback 用に維持する。
- `content/notes/` の Obsidian 同期記事10件から、Astro がホーム、研修一覧、ID 固定の個別記事 route を `dist/` に静的生成する。
- 新 Study App は説明文を置かないコンパクトな1列一覧と、記事 path の階層を示す Wiki 風サイドバーを全ページで表示する。階層フォルダは開閉でき、現在の記事と親階層を強調し、開閉状態をブラウザーに保存する。
- Frontmatter、ID / filename 一致、ID 重複、path 正規化を build 前に検証し、article master v2、link index、search index を `generated/` に出力する。
- Wiki Link は title / alias / filename / explicit path の候補を保持し、同名や未解決を自動で別記事へ結び付けない。教材中の生 HTML はコード表示へ変換する。
- 新 Study App は Standard、Wiki、Living Aurora、Blue Cosmos、Pulse Neon の5テーマを持ち、選択をブラウザーに保存する。
- 新ID単位の学習状態version 2を実装済み。読了、アクティブ閲覧中の学習時間、最終閲覧日時をlocalStorageへ保存し、`study`記事の集計とJSONバックアップ／復元を提供する。旧学習状態は自動移行しない。
- ホームと研修一覧で、タイトル・タグ・本文の複数語検索を提供する。ホームでは`study` / `wiki`の種別でも即時に絞り込める。
- 記事目次はPCで追従表示しながら開閉でき、スマホでは本文を圧迫しないよう閉じた状態で表示する。
- 外部 Obsidian Vault `Document organization` の `study/` / `wiki/` を記事の唯一の正本とし、`npm run vault:prepare -- "<Vault path>"` が検証付きで公開ミラー `content/notes/` と `dist/` を更新する。`content/notes/` は直接編集しない。
- 初期記事をVaultへ配置後、Obsidian上の追加・更新・削除を正本として同期している。現在は10件。
- 2026-10-01の同期で記事は8件。公開手順は`CONTENT_AUTHORING.md`に集約し、`vault:prepare`によるローカル準備とSitesへのdeployを区別する。生成結果テストは削除可能な公開記事の固定IDに依存せず、現行masterと独立fixtureで検証する。
- `sync-and-publish.cmd`または`npm run vault:publish`が同期・検証後にCodex CLIへ既存Sites公開を依頼する一括入口。CLIのSites接続と認証が必要で、自動承認reviewと公開statusの成功確認を維持する。CLI経由deployの実環境確認は未完了。

## 既知の制約・未解決事項

- `docs/password-gate.js` のパスワードは配信される JavaScript に平文で含まれる。これは閲覧 UI の抑止にすぎず、機密情報を保護する認証ではない。
- npm/package manifest、lint、typecheck、バンドル、依存関係固定、CI は存在しない。Docsify は実行時に jsDelivr CDN から読み込むため、オフラインでは完全に動作しない。
- ブラウザー UI 全体、Wiki リンク変換、reader tools、索引生成に対する自動テストは限定的または存在しない。
- 外部 Vault のバックアップ方針、対象ブラウザー、最終 custom domain、運用責任者は未確定。
- `docs/臨時フォルダ/`、`docs/保管用・未リンク/` や名前に「無題のファイル」を含む記事は整理候補に見えるが、独立した価値と外部正本が不明なため廃止候補とは確定していない。

## 現在の優先事項・次のアクション候補

既存343記事と旧学習状態の一括移行は行わない。次の作業は [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md) に沿った新規作成とReader機能である。

1. 必要な記事をObsidianで新しく作り直す。
2. unresolved / ambiguous Wiki Linkを人が解決する。
3. code copy、attachment、checklistを新ID向けに実装する。
4. Vault自体のprivate Git / backupと、Sites自動公開を整備する。

## 詳細への入口

- 構成とデータフロー: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- 現行機能と互換性: [`CURRENT_FEATURES.md`](CURRENT_FEATURES.md)
- 新データモデル: [`DATA_MODEL.md`](DATA_MODEL.md)
- Scratch & Build 計画: [`MIGRATION_PLAN.md`](MIGRATION_PLAN.md)
- 確認できた重要判断: [`decisions/ADR-001-static-docsify-and-generated-indexes.md`](decisions/ADR-001-static-docsify-and-generated-indexes.md)
- 新アーキテクチャ判断: [`decisions/ADR-002-astro-static-study-app.md`](decisions/ADR-002-astro-static-study-app.md)
- 今回の調査記録: [`sessions/2026-08-28-knowledge-bootstrap.md`](sessions/2026-08-28-knowledge-bootstrap.md)
