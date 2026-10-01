# Docsify表示初期化の修正

- 公開ホームで本文がsidebarの裏に隠れ、検索とnavigationが欠ける問題を確認。
- reader-toolsのapplyThemeが欠落したtheme-color metaへsetAttributeし、doneEachを途中で停止していた。公開ブラウザーconsoleのTypeErrorが根拠。
- ルートHTMLにmetaを復元し、共有reader-toolsはmetaがない場合も作成して初期化を継続する。
- ローカルのホームと本文を実ブラウザー確認。390px幅の本文は横はみ出しなし。14テスト・diff check成功。
- 記事やVault、保存済み学習状態は変更しない。
