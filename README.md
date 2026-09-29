# Study App

Git 管理された Markdown を正本とし、Study Web、Obsidian、Wiki、将来の AI / RAG から再利用できる学習基盤へ再構築するプロジェクトです。

## 現在の状態

Scratch & Build の Phase 1 として、Astro + TypeScript で一覧・研修一覧・個別記事を閲覧できる縦切り実装まで完了しています。Obsidian Vault の `study/` と `wiki/` を正本に、検証付き同期コマンドで `content/notes/` と `dist/` を生成します。

既存 `maruyamamasaya/study` の全記事と学習状態はまだ移行していません。Phase 1 の代表記事と Vault で新規作成された少数記事だけを扱います。

記事の追加方法と公開手順は [CONTENT_AUTHORING.md](CONTENT_AUTHORING.md) を参照してください。

## 設計資料

- [現行機能と互換性](CURRENT_FEATURES.md)
- [データモデル](DATA_MODEL.md)
- [移行計画](MIGRATION_PLAN.md)
- [現在の状態](CURRENT.md)
- [現行アーキテクチャ](ARCHITECTURE.md)

旧リポジトリは `maruyamamasaya/study`、新しい開発先は `maruyamamasaya/studyApp` です。
