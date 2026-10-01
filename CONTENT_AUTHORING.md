# 記事の編集・同期・公開

## 編集

記事はObsidian Vaultの`study/`または`wiki/`で編集します。`docs/`は生成ミラーなので直接編集しません。Vaultは既定でStudy Appの隣の`Document organization`です。

ID、filename、created、type、tagsのFrontmatterは現在のObsidianテンプレートを使います。IDを変更しないでください。

## 一括更新

`sync-and-publish.cmd`をダブルクリックします。コマンドからは次のとおりです。

```powershell
npm run vault:publish
```

1. Vaultを検証し、Markdownの追加・更新・削除をdocsへ反映します。
2. 記事一覧・Wiki Link索引を更新してテストします。
3. docsと同期manifestだけをcommitし、origin/mainへpushします。
4. GitHub ActionsがdocsをPagesへ公開します。Actionsで成功を確認してください。

AI・Codex・API key・Sitesを使用しません。初回だけNode.js、Python 3、Git、GitHub認証、npm install、GitHub Pages設定が必要です。

## ローカルで確認

```powershell
npm run vault:prepare
npm run dev
```

`http://127.0.0.1:8000/`を開きます。PythonがPATHにない場合は`STUDY_APP_PYTHON`にPython実行ファイルの絶対pathを設定してください。このPCでは既存bundled Pythonも検出します。

Vaultを変える場合:

```powershell
npm run vault:prepare -- "C:\path\to\Vault"
```

同期予定だけ確認する場合は`npm run vault:check -- "<Vault path>"`です。

## 失敗したとき

検証・Gitエラー時は停止します。同期先を直接編集した場合はVaultへ修正を戻し、差分を確認してください。Git履歴分岐は手動で確認し、force pushで解消しないでください。

GitHubへのpush成功は公開成功ではありません。初回Pages未設定やActions失敗時はサイトが更新されません。Sitesの旧URLとは別の公開先です。

Pagesの公開サイトとMarkdownは誰でも閲覧できます。秘密情報は記事へ含めないでください。非公開repositoryのPages利用可否はGitHubプランに依存します。
