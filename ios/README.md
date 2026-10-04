表示名: **Learnleaf**（ホーム画面・記事ホーム）。

# iOSアプリの開発とMacでの確認

Windowsで作成した初期実装を2026-10-02にMacで検証。Xcode 26.6でSimulatorの23件XCTestが成功し、Vespera（iPhone 17e）への開発署名付きビルド・インストール・起動を確認した。読書・音声の手動確認は以下の項目が残る。

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

XcodeのProduct > TestでXCTestを実行する。Simulatorを使う場合は、以下の運用ルールに従ってテスト設定の並列実行を無効にする。hash、URL、一覧Schema・重複、Frontmatter・コード内リンク保護、リンク解決、記録の再起動・復元・重複防止、破損ファイル保護、音声の管理JSON・取り込み・台本・再生位置・BGM保存を確認する。

CLIの場合、先に利用可能なSimulatorを確認する。

```sh
xcodebuild -project StudyApp.xcodeproj -scheme StudyApp -showdestinations
```

次のSIMULATOR_IDは上の一覧にあるidへ置き換える。

```sh
xcodebuild -project StudyApp.xcodeproj -scheme StudyApp \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 test
```

### Simulator運用ルール

Simulator上の単体・回帰・UIテストすべてに適用する。清掃は実行した開発エージェントが行う。自動清掃スクリプトは導入しない。

- 通常は既存端末1台を再利用し、`xcodebuild test` / `test-without-building`には上記の`-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`を必ず指定する。同じ端末へのテストを同時起動しない。
- 並列実行が必要な場合は理由を実行記録に明示し、worker数を最大2に制限する。CLIでは`-parallel-testing-enabled YES -parallel-testing-worker-count 2 -maximum-parallel-testing-workers 2 -maximum-concurrent-test-simulator-destinations 2`を指定する。Xcodeから実行する場合も同等の制限を設定する。並列数の制限だけでは残存端末の蓄積を防げないため、以下の記録・清掃も行う。
- 実装中は必要な対象テストに絞る（CLIでは`-only-testing:`などを使う）。最終変更後に必要な全体テストを実行し、変更・失敗・未解決の確認事項がない状態で全体テストを繰り返さない。

#### 実行前後の記録

テスト実行前と、成功・失敗どちらでもテストプロセスと子プロセスが終了した後に、次のコマンドでXCTest用device setの端末IDと状態を記録する。

```sh
xcrun simctl --set ~/Library/Developer/XCTestDevices list devices -j
```

JSON出力、取得の成否、実行日時、使用した通常端末のUDID、実行コマンド、プロセス情報、作成された複製と今回の実行との対応を示すログ等を、実行ごとに区別して保存する。中断後にも参照できるよう記録の保存先を作業記録に残す。コマンドの失敗やJSONの読み取り失敗は「端末なし」と扱わず、確認不能として報告する。

端末名や実行前後のID差分は候補の抽出に使えるが、それだけで所有を断定しない。今回の実行が複製を作成したと確認できる記録を必要とする。他の実行と重なった場合や作成元が不明な場合は削除せず、対象IDと確認できない理由を報告する。

#### 終了後の清掃

1. テストの成功・失敗にかかわらず、テストプロセスと子プロセスがすべて終了したことを確認する。終了を確認できない間は削除しない。
2. 自分の実行で作成したと確認できる複製だけを候補にし、削除直前に上記の`list devices -j`を再取得して、対象UDIDが同じdevice setで停止中（`Shutdown`）であることを再確認する。取得失敗、所有不明、起動中の場合は削除しない。
3. 確認できたUDIDを1件ずつ、同じdevice setを指定して削除する。次の`UDID`は確認済みの対象IDへ置き換える。

   ```sh
   xcrun simctl --set ~/Library/Developer/XCTestDevices delete UDID
   ```

4. 同じdevice setの`list devices -j`を再取得し、削除対象IDが消えたことを確認する。削除数、残存数（今回の複製とdevice set全体を区別）、清掃失敗とその理由を報告する。再取得に失敗した場合は削除完了や残存0を断定しない。`du`の容量を、そのまま回復した空き容量として報告しない。

通常端末、起動中端末、他の作業の端末、OSランタイム、テスト結果・ログは削除しない。`delete all`やディレクトリの直接削除は使わない。

中断で清掃できなかった場合は未清掃の対象IDと記録の保存先を残す。次回は保存した記録を確認し、プロセス終了、自分の実行による所有、削除直前の停止状態を確認できる複製だけを同じ手順で清掃する。確認できないものは削除せず報告する。

## 手動確認

- 日本語の長い記事、表、コード、ダークモード、文字サイズ、VoiceOver。
- 検索、フォルダ、未読了絞り込み、引っ張って一覧更新。
- Wiki Linkと通常の相対Markdownリンク。候補が複数の場合の選択、未解決リンク、外部リンク。
- 機内モード、404、5xx、hash不一致、未対応Schemaからの再試行。
- 本文取得完了後に計測開始、読了後停止、記事移動・別タブ・候補画面・バックグラウンド中に時間が増えないこと。
- 再起動後の読了と時間、JSON書き出し・復元キャンセル・復元、壊れたバックアップの拒否。
- 記事移動でも同じIDの記録が維持され、記事削除後も履歴が残ること。

## 初期実装の制限

見出しリンクは記事の先頭を開く。見出しへのスクロール、画像・添付、記事のオフライン保存、日別集計と日付またぎの配分、復習モード、クラウド同期は未実装。履歴は設定の「学習記録」から開く。記事ごとに合計時間を表示し、最新の学習順に並べる。下部タブは記事・聴く・番組・フォルダ・設定。本文の埋め込みHTMLと画像の描画はMacで検証する。任意JavaScriptを実行するWebViewは使用しない。

時間はmonotonic uptimeで測り30秒ごとに保存する。OSが保存の機会なくアプリを終了した場合、最後の未保存区間は最大約30秒失われ得る。アプリのバックアップ復元中は計測中の記事を開かない。WindowsではSwiftツールチェーンを導入していないため、ビルド成功・テスト成功を判定できていない。

## 事前生成音声

設定の「音声・同期」から、iCloud Drive等の制作物フォルダとBGMを取り込める。「聴く」は音声一覧、「番組」は番組一覧と再生順・曲間の設定を表示する。記事の「この記事を聴く」は再生ページを直接開く。聴く/番組の下部のミニプレイヤーから再生ページを開き直せる。フォルダ同期と管理JSONによる自動紐付け、同じtrackIDの差し替えと台本の取り込み、端末内コピーの再生、位置保存、倍速、BGM、バックグラウンドとロック画面の操作を実装した。生成処理は追加していない。受け入れ形式と実機確認は[AUDIO_IMPORT.md](AUDIO_IMPORT.md)を参照する。XcodeGenを再生成し、Background Audio設定を反映してから確認する。

## 学習番組

番組の再生順、連続再生、0〜10秒のインターバル、BGM、最後の番組の途中再開を追加した。制作側の番組JSONとMacでの確認手順は[RADIO_PLAYBACK.md](RADIO_PLAYBACK.md)。ビルド・23件のXCTestはMacで成功。音声の実機操作は手動確認が残る。

## アイコンと実機ビルド

抽象的な青緑・紫のアイコンをResources/Assets.xcassetsに配置した。XcodeGen再生成で反映する。署名TeamはXcodeまたはxcodebuildのDEVELOPMENT_TEAMでローカル指定する。共有project.ymlには個人Teamを保存しない。

Macの既定Nodeが16の場合、既存テストとHTTP配信検証にはNode 18以降を選択する。今回はHomebrewのNode 24を使用した。公開一覧の54記事すべての取得と本文hash一致を確認済み。

## 記事を探す・保存する

記事ホームには前回の記事、日替わりのピックアップ3件、タグ、フォルダ、自分の本棚を表示する。ピックアップは入れ替えボタンで変更できる。タグとフォルダの一覧から検索・未読了絞り込みが可能。フォルダは祖先以下の記事を含み、開閉状態を端末内へ保存する。

記事右上の保存ボタンでお気に入りとコレクションを管理する。コレクションは本棚で作成・名前変更・削除でき、詳細の追加ボタンで記事を追加/解除する。コレクションの記事を長押しして外せる。原本のフォルダは変更しない。お気に入り・コレクションも学習記録JSONの書き出し/復元に含み、以前のv1バックアップも読み込める。前回の記事は記事単位で開き直す。スクロール位置の復元は未対応。
