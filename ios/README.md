# iOSアプリの開発とMacでの確認

Windowsで初期実装を作成済み。Xcodeのビルド、Swiftの型検査、XCTest、Simulator・実機での動作は未確認。実機導入前に以下を実施する。

## 構成

SwiftUI、iOS 17以降を対象とする。記事はPagesの `app-articles.v1.json` とMarkdownをHTTPS取得する。Webサイト全体の読み込みは行わない。記事一覧、タイトル・タグ・alias検索、フォルダ選択、未読了絞り込み、本文、内部リンク、読了、学習時間、履歴、バックアップを実装した。

本文は[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1のSwiftUI部品で描画する。表・コードを扱うため採用した。同ライブラリはmaintenance modeのため、Macで描画と依存解決を確認し、将来の移行は別途判断する。プロジェクトは[XcodeGen](https://github.com/yonaskolb/XcodeGen)で `project.yml` から生成する。生成したXcode projectはGit管理外。

学習記録はApplication Supportの `StudyApp/records.v1.json`。保存はatomic書き込みで、Web記録とは独立する。壊れた保存ファイルを空データで上書きしない。復元は形式検証と確認後に全置換し、同一セッションを重複追加しない。SwiftDataやクラウド同期は導入していない。

## Macでの開始手順

1. この作業を含むリポジトリをMacへコピーするか、commit/push後に取得する。現在の未commitファイルはcloneだけでは取得できない。
2. 配信ファイルを公開する。リポジトリルートで通常の `npm run vault:publish` を実行し、Pagesのdeploy成功後に `npm run app:verify -- https://maruyamamasaya.github.io/studyApp/` を確認する。MacにVaultがない場合はWindows側で公開する。
3. MacにXcodeとcommand line toolsを準備する。Homebrewを使う場合は `brew install xcodegen` でXcodeGenを導入する。
4. Macのターミナルで以下を実行する。

```sh
cd ios
xcodegen generate
open StudyApp.xcodeproj
```

XcodeでStudyApp schemeと利用可能なiPhone Simulatorを選び、Runする。実機ではSigning & Capabilitiesから自分のTeamを選ぶ。Bundle Identifierが競合する場合は `project.yml` の値を変更して再生成する。Appleアカウントの資格情報をリポジトリへ保存しない。

## 自動テスト

XcodeのProduct > Testで23件のXCTestを実行する。hash、URL、一覧Schema・重複、Frontmatter・コード内リンク保護、リンク解決、記録の再起動・復元・重複防止、破損ファイル保護、音声の管理JSON・取り込み・台本・再生位置・BGM保存を確認する。

CLIの場合、先に利用可能なSimulatorを確認する。

```sh
xcodebuild -project StudyApp.xcodeproj -scheme StudyApp -showdestinations
```

次のSIMULATOR_IDは上の一覧にあるidへ置き換える。

```sh
xcodebuild -project StudyApp.xcodeproj -scheme StudyApp \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' test
```

## 手動確認

- 自由なtypeに対応した版への更新後、Applied・development-log・未指定の記事が一覧に表示され、本文を開けること。旧版は許可リストにない種別を拒否して一覧全体の形式エラーになる。Webの再公開だけでは端末内の検証処理は更新されない。

- 日本語の長い記事、表、コード、ダークモード、文字サイズ、VoiceOver。
- 検索、フォルダ、未読了絞り込み、引っ張って一覧更新。
- Wiki Linkと通常の相対Markdownリンク。候補が複数の場合の選択、未解決リンク、外部リンク。
- 機内モード、404、5xx、hash不一致、未対応Schemaからの再試行。
- 本文取得完了後に計測開始、読了後停止、記事移動・別タブ・候補画面・バックグラウンド中に時間が増えないこと。
- 再起動後の読了と時間、JSON書き出し・復元キャンセル・復元、壊れたバックアップの拒否。
- 記事移動でも同じIDの記録が維持され、記事削除後も履歴が残ること。

## 初期実装の制限

見出しリンクは記事の先頭を開く。見出しへのスクロール、画像・添付、記事のオフライン保存、日別集計と日付またぎの配分、復習モード、クラウド同期は未実装。履歴は保存した計測区間を日時順に表示する。本文の埋め込みHTMLと画像の描画はMacで検証する。任意JavaScriptを実行するWebViewは使用しない。

時間はmonotonic uptimeで測り30秒ごとに保存する。OSが保存の機会なくアプリを終了した場合、最後の未保存区間は最大約30秒失われ得る。アプリのバックアップ復元中は計測中の記事を開かない。WindowsではSwiftツールチェーンを導入していないため、ビルド成功・テスト成功を判定できていない。

## 事前生成音声

「聴く」タブと記事画面から、iCloud Drive等のファイルを取り込める。フォルダ同期と管理JSONによる自動紐付け、同じtrackIDの差し替えと台本の取り込み、端末内コピーの再生、位置保存、倍速、BGM、バックグラウンドとロック画面の操作を実装した。生成処理は追加していない。受け入れ形式と実機確認は[AUDIO_IMPORT.md](AUDIO_IMPORT.md)を参照する。XcodeGenを再生成し、Background Audio設定を反映してから確認する。

## 学習番組

番組の再生順、連続再生、0〜10秒のインターバル、BGM、最後の番組の途中再開を追加した。制作側の番組JSONとMacでの確認手順は[RADIO_PLAYBACK.md](RADIO_PLAYBACK.md)。ビルド・23件のXCTest・実機検証はMacでまとめて行う。
