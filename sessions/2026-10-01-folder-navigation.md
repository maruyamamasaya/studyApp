# フォルダ構成を表示するsidebar

- metadataのpathからフォルダ階層を構築。静的な記事一覧だけではVault構成が見えない問題を修正。
- native detailsで開閉、localStorageで状態保存、現在の記事の祖先を展開。表示名は記事title、長い名前はellipsisとtitle属性。
- sidebarの本文見出し混在はsubMaxLevel=0で抑え、目次drawerを維持。
- ローカルブラウザーでwiki/anken003の祖先展開・選択状態、anken001の開閉を確認。14テスト、JS構文検査、diff check成功。
- Vault・記事・同期方式の変更なし。
