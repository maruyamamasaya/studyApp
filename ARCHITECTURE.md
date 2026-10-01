# アーキテクチャ

更新: 2026-10-01

```text
Obsidian Vault / study・wiki
  ↓ 検証と一方向同期（Node.js）
docs/study・docs/wiki のMarkdown
  ├─ _article-metadata.json（title・alias・ID）
  ├─ README.md・_sidebar.md・training/README.md
  └─ build_note_index.py → _note-index.json・_article-master.json
  ↓ commit / push
GitHub repository
  ↓ GitHub Actions（HTML buildなし）
GitHub Pages → DocsifyがブラウザーでMarkdownを描画
```

- `scripts/lib/article.mjs`: YAML、Frontmatter、ID、created、重複の検証。依存はyamlのみ。
- `scripts/sync-obsidian-content.mjs`: Vaultからdocsへの同期。`obsidian-sync-manifest.json`のhashで管理し、直接変更・管理外上書き・不正な削除pathを拒否する。空ファイルは下書きとして除外する。
  保存フォルダと記事種別は独立し、相対パスとFrontmatterを維持する。typeはstudy/wikiを検証し、研修一覧はtypeがstudyの記事を配置場所によらず掲載する。
- `scripts/prepare-obsidian-content.mjs`: 同期、Python索引生成、テスト、diff check。
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
