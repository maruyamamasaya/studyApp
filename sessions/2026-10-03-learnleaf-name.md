# Learnleafへの名称変更

- 依頼: Learnleafをアプリ名に採用し、ラジオ編集の方法を説明。
- 実装: project.ymlのCFBundleDisplayNameと記事ホームのnavigationTitleをLearnleafへ変更。XcodeGen再生成。bundle IDを維持し、既存アプリへの更新として導入。
- ドキュメント: RADIO_PLAYBACKの同期導線を現行の設定/聴くへ更新。台本だけでは音声が変わらないこと、再生成・同期、番組JSONの名前/順序、アプリ内の曲間設定を説明。CURRENT/READMEに名称を記録。
- 検証: 実機ビルド成功。完成したInfo.plistのCFBundleDisplayNameがLearnleafであることを確認。Vesperaへ上書きインストール・起動成功。名前のみの変更なので追加のテストは作成しない。索引再生成差分なし、diff check成功。
- 残課題: 台本編集/番組並べ替えのアプリ内画面は未実装。名称の実機ホーム画面での目視確認はユーザー側。
