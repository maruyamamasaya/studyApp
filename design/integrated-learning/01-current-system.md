# 1. 既存Study Appの構成調査書
更新: 2026-10-08 / 調査基準: e1b201e

## 調査範囲と根拠

AGENTS、CURRENT、ARCHITECTURE、CONTENT_AUTHORING、APP_ARTICLE_DELIVERY、ios/README、関連ADRとコード・Git履歴を確認。docsの記事は全読せず、入口・共有JS・生成工程を調査。CURRENT等には初期段階の文言も残るため、現行コードとADR-017を優先して判定した。

| 観点 | 現行実装と根拠 | 拡張時の扱い |
| --- | --- | --- |
| 構成 | docs/index.html・training/index.html、共有JS/CSS、静的Docsify。ios/project.ymlはiOS17+ SwiftUI/XcodeGen | 同じリポジトリで継続、Astro/Sitesへ戻さない |
| 依存 | package.jsonはyaml 2.8.1。WebはDocsify@4、DOMPurify 3.2.7をCDN取得。iOSはMarkdownUI 2.4.1 | 全面変更不要、新viewerだけ遅延読み込み |
| Markdown | Vault/wiki正本→scripts/sync-obsidian-content.mjs→docs/wiki。WebはDocsify、iOSはStudyApp.swiftのMarkdownUIとArticleLinks | 記事描画、Wiki Link処理を再利用 |
| metadata | lib/article.mjsでFrontmatter/ID検証。_article-metadata.json、_note-index.json、_article-master.json、app-articles.v1.jsonを生成 | 記事IDは変更せず、リソース索引を別契約で追加 |
| 添付 | walkMarkdownはMarkdownのみ同期。既存favicon等の静的資産はあるが、Vault添付管理は未実装 | 原本・画像・SVGの同期/検証を新設 |
| 検索 | Web reader-tools.js等に検索。iOS SearchEngine/SearchPreferencesで記事・音声・番組、タグ・フォルダ・状態・履歴・保存条件 | metadata/抽出テキストを追加対象にする。全文取得は明示操作 |
| 保存一覧 | iOS LibraryViews/StudyStoreにお気に入り・コレクション。Webと同機能と推定しない | 記事ID配列を壊さず別のリソース保存一覧から開始 |
| モバイル | Webは900px以下でdrawer・下部操作。iOSはiPhone/iPad・Dynamic Type・テーマ | viewerを既存NavigationStackへ追加、本文領域を確保 |
| Git同期 | Vault→生成ミラー→commit/push→Pages。iOSはHTTPS、Git clone/API token不要 | 生成物の上書き保護とhash契約を継承 |
| 個人記録 | WebはlocalStorage、iOS StudyStoreのatomic JSON。記録転送はv1 JSON明示統合 | サーバーDBや自動クラウド同期はない |
| オフライン | iOS OfflineArticles actorがcatalog/本文hash検証し端末保存。WebはCDN依存、完全offline未対応 | 添付の容量管理は追加設計、Webには別途対応が必要 |
| 関連機能 | RelatedContentは共通タグ、ArticleLinksはID/path/title/alias、音声はarticleID/trackID | 明示関連と図解要素リンクを補う |
| ドキュメント | PDF/Office専用viewer、slide生成、SVG図解ライブラリは確認できない | 音声importの検証→端末コピーという責務分離を参考にする |

## データ保存と実際の通信

Learnleaf ArticleClient.swiftがapp-articles.v1.jsonと本文をHTTPS取得し、本文の改行正規化SHA-256を検証。OfflineArticles.swiftがApplication Supportへcatalog/本文を保存。StudyStoreは学習記録、UserDefaultsはテーマ/検索条件等を保存。WebのlocalStorageとは同期されない。音声は別の制作物フォルダから端末コピーしておりPages公開ではない。

## 調査時点の制約

10/8の同期チェックは既存生成ミラーの上書き保護で停止。原因は未確定で[既存課題](../../sessions/2026-10-08-vault-sync-issue.md)に記録済み。今回修正しない。既存SVGがimg等で表示できる場合でも、ズーム・安全な要素リンク・iOS表示を実装済みとは扱わない。Macの新規ビルド/実機測定は今回は行っていない。

## 関連する判断

[ADR-006](../../decisions/ADR-006-docsify-and-git-sync.md)、[ADR-008](../../decisions/ADR-008-ios-shared-articles.md)、[ADR-009](../../decisions/ADR-009-app-article-catalog.md)、[ADR-017](../../decisions/ADR-017-offline-articles-and-record-transfer.md)。既存機能を再実装せず、追加部分は[基本設計](04-system-design.md)へ分ける。
