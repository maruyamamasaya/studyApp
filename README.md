# Study App

Obsidian Vault の Markdown を正本とし、Study Web、Wiki、将来の AI / RAG から再利用できる学習基盤へ再構築するプロジェクトです。

## 現在の状態

Astro + TypeScript で一覧・研修一覧・個別記事を静的生成します。Obsidian Vault の `study/` と `wiki/` が唯一の編集元で、検証付き同期コマンドが Git 管理された公開ミラー `content/notes/` と `dist/` を生成します。

既存 `maruyamamasaya/study` の全記事と学習状態は移行しません。必要な記事は Obsidian で新しく作り直し、旧 `docs/` は参照用として変更せず残します。

記事の追加方法と公開手順は [CONTENT_AUTHORING.md](CONTENT_AUTHORING.md) を参照してください。

## 設計資料

- [現行機能と互換性](CURRENT_FEATURES.md)
- [データモデル](DATA_MODEL.md)
- [移行計画](MIGRATION_PLAN.md)
- [現在の状態](CURRENT.md)
- [現行アーキテクチャ](ARCHITECTURE.md)

旧リポジトリは `maruyamamasaya/study`、新しい開発先は `maruyamamasaya/studyApp` です。
