# Obsidian正本化

## 決定

- Obsidian Vaultの`study/`と`wiki/`を記事の唯一の正本に変更した。
- 既存343記事と旧学習状態は一括移行せず、必要な資料を新規作成する。
- `content/notes/`は公開用の生成ミラーとして当面Git管理する。

## 実装

- `vault:prepare`が安全な削除も反映する厳密同期に変更した。
- Vaultにない管理外のミラー記事を同期時に拒否する検証を追加した。
- ホームと共通metadataからPhase 1 / 移行中の表現を外した。
- CURRENT、ARCHITECTURE、DATA_MODEL、MIGRATION_PLAN、authoring手順を新方針へ更新した。
- 初回の厳密同期で、Vault側ですでに削除されていた2記事をhash照合後に公開ミラーから除去し、更新済み1記事を反映した。現在の同期記事は10件。

## 残課題

- Vault自体のprivate Gitまたはbackupを用意する。
- clean checkoutでVaultまたは専用content repositoryを取得できるようになった後、`content/notes/`をGitから除外するか再判断する。

## 検証

- `vault:prepare`でVault 10件と公開ミラーを一致させ、差分0を確認した。
- 同期の正常系、管理外ミラー拒否、hash照合付きpruneを含む13件のdomain / sync testを通した。
- Astro buildと生成HTML 6件、旧Docsifyの既存Node test、`git diff --check`を通した。
