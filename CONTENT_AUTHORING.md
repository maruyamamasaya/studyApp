# 記事の編集・同期・公開

## 編集

記事はObsidian Vaultの`study/`または`wiki/`で編集します。`docs/`は生成ミラーなので直接編集しません。Vaultは既定でStudy Appの隣の`Document organization`です。

ID、filename、created、type、tagsのFrontmatterは現在のObsidianテンプレートを使います。IDを変更しないでください。

保存フォルダと記事種別は別に扱います。`wiki/anken001/`などの案件フォルダにも`type: study`の学習記事を置けます。同期は元の相対パスとFrontmatterを維持し、研修一覧は配置場所ではなく`type: study`を対象にします。対応するtypeは`study`と`wiki`です。

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

同期時には将来のiOS等のアプリ向けに`docs/app-articles.v1.json`も生成します。記事配信の形式とhash検証は[APP_ARTICLE_DELIVERY.md](APP_ARTICLE_DELIVERY.md)を参照してください。Web用一覧と学習記録の保存方式は維持します。

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

通常の同期・公開では成功の要約だけを表示します。追加・削除などのファイル別ログやテスト詳細は、コマンド末尾に`--verbose`を付けた場合だけ表示します。失敗時は詳細を表示し、pushを停止します。末尾空白や改行形式は記事編集として許容し、公開を止めません。Frontmatter・ID・同期先の上書き保護とテストは引き続き実行します。開発時の`git diff --check`は別途実行します。

検証・Gitエラー時は停止します。同期先を直接編集した場合はVaultへ修正を戻し、差分を確認してください。Git履歴分岐は手動で確認し、force pushで解消しないでください。

GitHubへのpush成功は公開成功ではありません。初回Pages未設定やActions失敗時はサイトが更新されません。Sitesの旧URLとは別の公開先です。

Pagesの公開サイトとMarkdownは誰でも閲覧できます。秘密情報は記事へ含めないでください。非公開repositoryのPages利用可否はGitHubプランに依存します。
