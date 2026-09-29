---
status: accepted
updated: 2026-09-29
---

# ADR-005: Obsidian Vault を記事の唯一の正本にする

## Context

記事の追加・修正はローカル Obsidian で行う頻度が高い。Study App repository の `content/notes/` と Vault の双方を正本にすると、更新競合、削除漏れ、どちらが最新かという判断が発生する。また、既存343記事と旧学習状態を機械移行するより、今後必要な資料を現在のschemaで作り直す方針が選択された。

## Decision

- `C:\Users\m-maruyama\Development\Document organization` の `study/**/*.md` と `wiki/**/*.md` を記事の唯一の正本にする。
- `content/notes/**/*.md` はGit / build / Sites向けの生成ミラーとし、直接編集しない。
- 通常の公開準備は `vault:prepare` を使い、追加・更新・安全に確認できた削除をミラーへ反映する。
- Vaultにないミラー記事は、過去の同期manifestで管理されている削除候補を除いてerrorにする。
- 旧 `docs/`、旧GitHub Pages、旧localStorageは参照用として維持し、新アプリへ一括移行しない。
- 必要な記事は新しいIDと作成時刻でObsidianに作り直し、旧IDや学習状態を推測して引き継がない。
- `content/notes/`は当面Git管理する。clean checkoutとSites buildの再現性を保つためであり、専用content repositoryまたはVault取得処理ができるまでignoreしない。

## Consequences

- 編集場所がObsidianに一本化される。
- Study App repositoryだけでは記事を編集せず、公開スナップショットとアプリ実装をreviewする。
- Vault自体には現在Git metadataがないため、private Gitまたは別backupが必要になる。
- 旧記事との完全な対応表や旧学習状態migrationは不要になる。
- 過去資料が必要な間は旧 `docs/` と旧サイトを削除できない。

## Supersedes

ADR-004の「Git / build上の正本を`content/notes/`とする」判断、および旧記事の一括migrationを前提とした計画を置き換える。ADR-004の一方向同期、hash照合、管理外上書き拒否は維持する。
