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
- `scripts/prepare-obsidian-content.mjs`: 同期、Python索引生成、テスト、diff check。
- `scripts/publish-obsidian.mjs`: mainとoriginを確認し、prepare成功後docsとmanifestだけをcommit/pushする。ステージ済みの無関係な変更があると停止する。force pushや自動mergeは行わない。
- `docs/index.html`と`docs/training/index.html`: Docsifyの入口。記事URLはhash route。HTTP serverで動作する。
- `docs/content-tools.js`: 表示時にFrontmatterを隠してtitleを付け、DOMPurifyで描画HTMLをsanitizeする。
- `docs/obsidian-wikilinks.js`: Wiki Linkのtitle・alias・filename索引からリンクを生成する。
- `docs/reader-tools.js`・`styles.css`・`unique-heading-ids.js`: 従来のテーマ、検索、学習状態、目次等の閲覧支援。
- `.github/workflows/pages.yml`: docsだけをPages artifactとして配信。秘密情報・Vault全体・保守資料をartifactへ含めない。

Astro・OpenAI Sites・Codex CLIによる公開経路は現行構成にない。DocsifyとDOMPurifyはjsDelivrを使うため完全offline閲覧は未対応。添付ファイル同期は未対応。公開は閲覧制限なしの構成であり、非公開repositoryでもPagesの閲覧は非公開にならない。
