---
status: superseded
updated: 2026-09-29
---

# ADR-004: Obsidian authoring source は検証付きで content/notes へ一方向同期する

> ADR-005 により、正本の位置と旧記事移行方針を置き換えた。同期の安全策は引き続き有効。

## Context

ローカルの Obsidian Vault `Document organization` では `study/` と `wiki/` に Templater で記事を作成する。一方、Study App は Git 管理された `content/notes/**/*.md` を build 上の正本とし、OpenAI Sites へ静的生成する。ブラウザーだけでローカル Vault を継続監視・更新し、認証済み Sites deployment まで永続化することはできない。

双方向同期は同じ ID の競合解決、削除伝播、編集中ファイルの扱いを追加で必要とし、Phase 1 の範囲を超える。旧 `docs/` は別の同期運用と学習状態を持つため変更できない。

## Decision

- 記事は Obsidian Vault の `study/**/*.md` と `wiki/**/*.md` で作成する。
- `scripts/sync-obsidian-content.mjs` が Vault から repository の同じ相対 path へ一方向同期する。
- Git / build / Sites に対する記事の正本は同期後の `content/notes/**/*.md` とする。
- 同期前に DATA_MODEL の Frontmatter、ID / filename、一意性、folder / type 一致を検証する。
- 0バイトの Markdown は下書きとして警告・除外し、削除しない。
- 同期管理外の既存ファイルは上書きしない。同期元から消えたファイルも既定では削除せず、過去 manifest の hash と一致する場合の明示 `--prune` だけを許可する。
- 公開操作はローカルの同期・検証・静的生成と、認証された OpenAI Sites 反映に分ける。

## Consequences

- Obsidian の folder template で作った記事を、1コマンドで検証して `dist/` まで生成できる。
- Vault と repository の手動二重編集は避ける必要がある。
- Sites 上の閲覧画面から Vault へ直接 upload / deploy はできない。
- 双方向同期、background watcher、CI からの自動 Sites deployment は将来の別判断となる。
