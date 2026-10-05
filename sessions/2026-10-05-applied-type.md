# Applied記事の公開エラー修正

- 原因: Vaultのwiki/study/Applied内で15記事のtypeがApplied、1記事が空欄。同期が許可するstudy/wiki/development-logに一致せず、push前の検証で停止した。
- 原本16記事のtypeのみstudyへ修正。フォルダ、ID、本文は維持。docsはvault:prepareで生成した。
- vault:prepare成功: 71記事、索引生成・テスト成功。git diff・status・diff --check確認。既存の未コミット変更は維持。
- テンプレートtemplates/wiki-template.mdはtypeが空欄。Appliedが入力された経緯は未確認。新規記事には許可された種別を入力する必要がある。
- 今回commit/pushは未実行。sync-and-publish.cmdで公開を再実行できる。
