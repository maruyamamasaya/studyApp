# 記事データ

原本はObsidian Vaultのstudy/・wiki/。公開ミラーはdocs内の同じ相対path。

- id: YYYYMMDD-HHmmss。filename stemと一致し、既存IDを変更しない。
- title: 文字列または空。空は未設定と表示する。
- type: 配置folderに一致するstudyまたはwiki。
- tags: 文字列配列。空配列可。
- created: Asia/Tokyoの実在するYYYY-MM-DD HH:mm:ss。
- aliases: 任意の文字列配列。
- updated: 任意。表示順やidentityに利用しない。

_note-index.jsonはfilename・title・alias・明示pathから拡張子なしpath配列へ対応する。
_article-master.jsonはversion 1でid・path・titleを持つ。Frontmatter IDを優先し、保守用一覧記事の既存IDも保持する。
obsidian-sync-manifest.jsonはrepository rootで同期済みpathとhashを管理する。

ブラウザーの学習状態はDocsify reader toolsのlocalStorageに保持する。旧Astro version 2からの自動移行は行わない。
