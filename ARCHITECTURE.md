# アーキテクチャ

更新: 2026-10-02

```text
Obsidian Vault / study・wiki
  ↓ 検証と一方向同期（Node.js）
docs/study・docs/wiki のMarkdown
  ├─ _article-metadata.json（title・alias・ID）
  ├─ app-articles.v1.json（アプリ用の版付き一覧・本文hash）
  ├─ README.md・_sidebar.md・training/README.md
  └─ build_note_index.py → _note-index.json・_article-master.json
  ↓ commit / push
GitHub repository
  ↓ GitHub Actions（HTML buildなし）
GitHub Pages → DocsifyがブラウザーでMarkdownを描画
             → iOSアプリ（初期コード、Mac未検証）がJSONとMarkdownをHTTPS取得
```

- `scripts/lib/article.mjs`: YAML、Frontmatter、ID、created、重複の検証。依存はyamlのみ。
- `scripts/lib/app-articles.mjs`: 検証済み記事からアプリ向け一覧を生成。schemaVersion、revision、ID、相対path、表示metadata、LF正規化後の本文hashを持ち、変更なしの生成で差分を出さない。Web用metadataとは独立する。
- `scripts/verify-app-catalog.mjs`: 指定配信元から一覧と全記事をHTTP取得し、形式・取得成功・本文hashを確認する読取専用CLI。契約はAPP_ARTICLE_DELIVERY.md。
- `scripts/sync-obsidian-content.mjs`: Vaultからdocsへの同期。`obsidian-sync-manifest.json`のhashで管理し、直接変更・管理外上書き・不正な削除pathを拒否する。空ファイルは下書きとして除外する。
  保存フォルダと記事種別は独立し、相対パスとFrontmatterを維持する。typeはstudy/wikiを検証し、研修一覧はtypeがstudyの記事を配置場所によらず掲載する。
- `scripts/prepare-obsidian-content.mjs`: 同期、Python索引生成、テスト。成功時は要約、失敗時は詳細を表示する。`--verbose`で詳細ログを表示する。日常の公開では記事の末尾空白を停止条件にしない（diff checkは開発時に別途実行）。
- `scripts/publish-obsidian.mjs`: mainとoriginを確認し、prepare成功後docsとmanifestだけをcommit/pushする。ステージ済みの無関係な変更があると停止する。force pushや自動mergeは行わない。
- `docs/index.html`と`docs/training/index.html`: Docsifyの入口。記事URLはhash route。HTTP serverで動作する。
- `docs/content-tools.js`: 表示時にFrontmatterを隠してtitleを付け、DOMPurifyで描画HTMLをsanitizeする。
- `docs/obsidian-wikilinks.js`: Wiki Linkのtitle・alias・filename索引からリンクを生成する。
- `docs/folder-navigation.js`: 記事metadataのpathからVaultのフォルダ階層を組み立て、開閉状態をブラウザーに保存する。現在の記事の祖先を開き、記事を強調する。研修サイトは独立した従来navigationを維持する。
- `docs/reader-tools.js`・`styles.css`・`unique-heading-ids.js`: 従来のテーマ、検索、学習状態、目次等の閲覧支援。
  学習状態・時間・チェックリスト等の保存処理を維持する。旧テーマCSSは使用しない。
- `docs/reader-shell.js`・`styles.css`: スマホ中心の新UI。900px以下はフォルダdrawer・下部検索/目次、901px以上は左sidebar・中央本文。記事名、tags、学習時間を本文先頭にまとめ、入口はmetadataから記事カードを構築する。overlay閉鎖とinertも管理する。
- `.github/workflows/pages.yml`: docsだけをPages artifactとして配信。秘密情報・Vault全体・保守資料をartifactへ含めない。

Astro・OpenAI Sites・Codex CLIによる公開経路は現行構成にない。DocsifyとDOMPurifyはjsDelivrを使うため完全offline閲覧は未対応。添付ファイル同期は未対応。公開は閲覧制限なしの構成であり、非公開repositoryでもPagesの閲覧は非公開にならない。

## iOSの初期実装

`ios/project.yml`をXcodeGenで生成する独立したiOS 17以降のSwiftUIアプリ。Pagesへは配信しない。

- `ios/Sources/ArticleClient.swift`: 専用一覧v1の検証、HTTPS取得、リダイレクト拒否、15秒の要求Timeout、最大3回の限定Retry、本文hash照合。
- `ios/Sources/ArticleLinks.swift`: Frontmatter除去、コード内を除くWiki Link変換、一覧内のID・path・title・alias解決。
- `ios/Sources/StudyStore.swift`: 独立した記録JSONのatomic保存、復元検証、monotonic uptimeでの計測区間。
- `ios/Sources/StudyApp.swift`: 一覧・検索・フォルダ・本文・履歴・設定、画面とアプリ状態による計測制御。本文はMarkdownUI。

プロジェクト生成・ビルド・テストはMacで行う。現時点の制約と手順は[ios/README.md](ios/README.md)を参照する。
