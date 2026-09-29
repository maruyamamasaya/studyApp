# Obsidian Vault 同期

## 調査

- `Document organization` は Git repository ではなく、Obsidian Vault。`study/` に空ファイル1件、`wiki/anken001/` に4記事があった。
- Templater は `wiki/` だけに folder template が設定され、既存 Wiki 4件には `type` がなかった。
- `Obsidian-plugin/obsidian-explorer-titles` に Git metadata はなく、Explorer 表示だけを変更する v1.0.1 の source と Vault 配備物があった。

## 実装

- Vault の `study/` / `wiki/` を検証付きで `content/notes/` へ同期する script、manifest、test、`vault:prepare` command を追加した。
- Phase 1 の7記事を type に合わせて Vault へ初期配置し、既存 Wiki 4件へ `type: wiki`、引用符付き `created`、`aliases: []` を明示した。
- Study / Wiki template を DATA_MODEL と揃え、Templater の folder mapping を両 folder に設定した。
- Explorer Titles の既定対象を `study` / `wiki` に変更し v1.0.2 として build・Vault deploy した。
- `updated` は optional な Obsidian 互換項目として受理するが、identity・表示順・学習状態には利用しない。

## 検証

- 同期 unit test は、正常同期、空下書き除外、folder / type 不一致、管理外上書き拒否を確認した。
- Vault で作成された新規 Study 記事を含む12件を検証し、空下書き1件を保持・除外した。
- Explorer Titles の TypeScript typecheck と production build を通した。
- `npm run check`、旧 Docsify の Node tests、`git diff --check` を通した。
- ローカル HTTP 上の実ブラウザーで12件の一覧、直接URL / reload、ID付き Wiki Link、空 title の `未設定` 表示、テーマ保持、HTML例の非実行、console error なしを確認した。

## 残課題

- legacy 343記事、既存 localStorage、旧 `docs/` は未移行。
- Vault / plugin directory 自体の Git・バックアップ方針は未設定。
- Sites の完全自動 deploy、双方向同期、background watcher は未実装。
