# Study App

Git 管理された Markdown を正本とし、Study Web、Obsidian、Wiki、将来の AI / RAG から再利用できる学習基盤へ再構築するプロジェクトです。

## 現在の状態

Scratch & Build の Phase 1 として、代表記事7件を Astro + TypeScript で静的生成し、一覧・研修一覧・個別記事を閲覧できる縦切り実装まで完了しています。

既存 `maruyamamasaya/study` の全記事と学習状態はまだ移行していません。Phase 1 では5件だけ本文をコピーし、対応関係を `migration/phase1-samples.json` に記録しています。

記事の追加方法と公開手順は [CONTENT_AUTHORING.md](CONTENT_AUTHORING.md) を参照してください。

## 設計資料

- [現行機能と互換性](CURRENT_FEATURES.md)
- [データモデル](DATA_MODEL.md)
- [移行計画](MIGRATION_PLAN.md)
- [現在の状態](CURRENT.md)
- [現行アーキテクチャ](ARCHITECTURE.md)

旧リポジトリは `maruyamamasaya/study`、新しい開発先は `maruyamamasaya/studyApp` です。
