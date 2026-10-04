# MacでのiOS検証とVesperaへの導入

ユーザー承認: Mac上の確認、Vesperaへの直接デプロイ、抽象的なアイコン作成。

Xcode 26.6を確認し、XcodeGen 2.46.0を導入。project.ymlからプロジェクトを生成。ArticleReaderのcatch内でerrorが暗黙のErrorを指すコンパイルエラーをself.errorへの代入に修正した。imagegenで抽象的な青緑・紫のアイコンを生成し、1024pxに変換してAsset Catalogへ追加。ResourcesとAppIcon設定をproject.ymlへ追加。

検証: iPhone 17e Simulator（iOS 26.5）で23件のXCTest成功。既存ローカルTeamで開発署名し、Vespera（iPhone 17e）へインストール・起動成功。署名Teamは共有設定へ固定していない。Node 16では既存テスト・fetchが未対応のためHomebrew Node 24を選択し、npm ci後に20テスト成功。公開配信の54記事のHTTP取得とhash一致。Simulatorの起動画面で記事一覧・検索欄・フォルダ・4タブの表示を目視確認。索引再生成の差分なし。git diff --check成功。

残課題: File Provider/bookmark、実際の音声取り込み・連続再生・ロック画面・割り込み・読書計測・バックアップの実機手動確認。実機ビルドのiPad画面回転対応warningは残る。AppIntents未使用のmetadata warningも出る。commit/pushは今回行わない。

追記: ユーザーから実機アイコン未反映の報告。初回のproject.ymlのトップレベルresources指定はXcodeGenに取り込まれず、初回配布物にAssets.carとCFBundleIconsが欠落していた。sourcesのResourcesエントリにbuildPhase: resourcesを指定して修正。前回のアイコン反映済みの記録は誤り。再ビルド成功。配布物にCFBundleIcons/CFBundleIcons~ipad、AppIcon画像、Assets.carが含まれることを確認し、Vesperaへ上書きインストール成功。索引差分なし、diff check成功。実機ホーム画面の目視はユーザー側での確認が残る。
