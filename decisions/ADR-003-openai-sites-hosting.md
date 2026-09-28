---
status: accepted
updated: 2026-09-28
---

# ADR-003: 新 Study App は OpenAI Sites で配信する

## Context

ADR-002 では GitHub Pages を初期 hosting 候補としていた。その後、新サイトの配信先を OpenAI Sites に変更する方針が明示された。既存 Docsify と学習データの移行はまだ完了していないため、旧サイトを直ちに置き換えると rollback 手段を失う。

## Decision

- 新 Study App の配信先を OpenAI Sites とする。
- Sites のプロジェクト設定は `.openai/hosting.json`、公開対象は `dist/` に分離する。
- 新サイトは非公開で開始する。
- 旧 GitHub Pages は、`MIGRATION_PLAN.md` の cutover 条件を満たすまで維持する。
- Astro の採用、静的生成、コンテンツと学習状態の分離という ADR-002 の判断は維持する。

## Consequences

- GitHub Pages 固有の repository base path と Pages 用 Action は新サイトに不要になる。
- 公開範囲は Sites 側で管理でき、クライアント側 password gate を認証として移植する必要がない。
- 現時点の Sites 初期版は移行状況を示す静的ページであり、学習記事の移行完了を意味しない。
- legacy site を残すため、移行中に問題があっても既存の閲覧先へ戻せる。

## Supersedes

ADR-002 の hosting 候補に関する記述を置き換える。アプリケーション構成に関する判断は置き換えない。
