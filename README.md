# Study App

Git 管理された Markdown を正本とし、Study Web、Obsidian、Wiki、将来の AI / RAG から再利用できる学習基盤へ再構築するプロジェクトです。

## 現在の状態

Scratch & Build の Phase 0（現行調査、データモデル、移行計画、技術選定）まで完了しています。新実装は Astro + TypeScript の静的生成を予定しています。

既存 `maruyamamasaya/study` の学習 Markdown は、初期 bootstrap には含めていません。legacy UUID と学習状態の移行方法を実装・検証してから、別フェーズで安全に取り込みます。

## 設計資料

- [現行機能と互換性](CURRENT_FEATURES.md)
- [データモデル](DATA_MODEL.md)
- [移行計画](MIGRATION_PLAN.md)
- [現在の状態](CURRENT.md)
- [現行アーキテクチャ](ARCHITECTURE.md)

旧リポジトリは `maruyamamasaya/study`、新しい開発先は `maruyamamasaya/studyApp` です。
