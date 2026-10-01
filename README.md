# Study App

Obsidianの記事をDocsifyで読む静的サイトです。記事はVaultの`study/`・`wiki/`で編集し、`docs/`へ一方向に同期します。

## 普段の更新

`sync-and-publish.cmd`をダブルクリックするか、次を実行します。

```powershell
npm run vault:publish
```

同期・索引更新・テストの後、`docs/`と同期manifestだけをcommitしてGitHubへpushします。Pages設定済みならGitHub Actionsが`docs/`をそのまま公開します。AIやCodexは起動しません。push完了とサイト公開完了は別で、結果はGitHubのActions画面で確認します。

ローカル同期だけなら`npm run vault:prepare`。起動前に`npm install`が必要です。Node.js、Git、Python 3を使います。

詳細は[CONTENT_AUTHORING.md](CONTENT_AUTHORING.md)、状態は[CURRENT.md](CURRENT.md)、構成は[ARCHITECTURE.md](ARCHITECTURE.md)を参照してください。
