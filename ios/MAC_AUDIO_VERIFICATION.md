# 音声機能のMac・実機検証（2026-10-05）

対象main: `2a9fbdffff87074bf22b1351aca29964adb0e938`。静的確認と実行結果を区別する。Xcodeビルド・型検査・XCTest・実機は未実行。VOICEVOX制作ツールは対象外。

## 1. 日中に確認したこと

| Windows / GitHubで確認可能 | 今回の確認結果 |
| --- | --- |
| mainのSHAと仕様・実装対応 | 指定SHAと一致。音声の全8 Swiftファイル、3テストファイル、project.ymlをレビュー |
| XcodeGen定義 | iOS 17、Swift 5、MarkdownUI 2.4.1、StudyAppTestsの依存とscheme、UIBackgroundModes: audioあり |
| XCTestの本数と対象 | 記事・記録7、音声10、番組6の計23。AVAudioPlayer/TrackPlayerの実際の再生、bookmark復元はテストされない |
| 同期の入力・保存経路 | ID付け替え、重複、参照不足の拒否、hash同一時の位置維持、別ローカルファイルへの差し替え、一覧atomic保存を確認 |
| 再生経路 | delegateによる番組遷移、無音PCMのインターバル、割り込み・経路切断停止、ロック画面コマンドを確認 |
| compile/test risk | 明白なコンパイルエラー・必ず失敗するXCTestは静的レビューでは見つからず。アプリコードの変更なし。型検査合格とは扱わない |

Mac必須: Apple SDKの型検査、MarkdownUI依存解決、XcodeGen生成、iOS Simulatorでの23 XCTest。実機必須: File Provider/iCloud権限とbookmark、バックグラウンドでの音声終了delegate、ロック画面、着信・イヤホン切断。Simulator成功でこれらを代替しない。

## 2. 日中の準備（夜に音源を作らない）

- 検証専用iCloudフォルダを用意し、区別できる短い音声A/B（各20〜30秒）、任意の短いBGM、UTF-8台本、2つのtrack JSON、1つのplaylist JSONを置く。実運用フォルダを編集しない。
- [AUDIO_IMPORT.md](AUDIO_IMPORT.md)のv1形式を使う。記事IDは`docs/app-articles.v1.json`の実在ID、trackIDは異なるUUID。音声は手元の再生可能ファイルを使えばよい。
- [RADIO_PLAYBACK.md](RADIO_PLAYBACK.md)の番組配列を**B→A**にして、ファイル名順と異なる順番を確認。間隔は3秒。
- 音声Aの別内容の差し替え版と、不足trackIDを指す番組JSONも別フォルダに準備。管理JSONは最後に保存し、通常セットはiPhoneでダウンロード済みにする。
- 未ダウンロード確認用は別ファイルを用意。検証の途中に通常セットを壊さない。

## 3. 夜のMac手順（失敗した段階で止める）

Macの既存checkoutで未commit変更がないことを`git status --short`で確認。mainへ移動して`git pull --ff-only`する。この手順をPRブランチで使うならそのブランチを取得し、`git rev-parse HEAD`を結果とともに記録する。mainが対象SHAから進んだ場合、追加差分のレビューが必要。

1. フルXcodeを起動し初回セットアップを済ませる。`xcode-select -p`がCommandLineToolsだけを指す場合はXcode > Settings > Locationsで使用するXcodeを選ぶ。XcodeGenがなければ`brew install xcodegen`。
2. repositoryルートから以下を実行。最初の呼び出しは生成とdestination表示まで行い、終了コード2で止まる。表示された**iOS Simulatorのid**を2回目へ渡す。

```sh
bash ios/scripts/verify-mac.sh
bash ios/scripts/verify-mac.sh SIMULATOR_ID
```

スクリプトはXcodeGen → 生成Info.plistの背景音声設定表示 → package解決 → build-for-testing（アプリとテストの型検査・ビルド）→ test-without-buildingの順。pipefailでログ保存中も失敗を検知する。出力先は一意の一時フォルダで、再実行時にxcresultが衝突しない。

3. `tests.log`またはXcodeで`Tests.xcresult`を開き、**23件実行・失敗0件**を確認。0件や一部のみの実行を合格にしない。ログ、SHA、Xcode版、Simulator OSを記録する。失敗時は最初のcompiler/test errorを解決して同じ順に再実行する。
4. `open ios/StudyApp.xcodeproj`。StudyApp scheme、接続したiPhoneを選び、Signing & Capabilitiesで自分のTeamを設定してRun。Simulator検証は署名不要。実機はDeveloper Mode・信頼設定が必要なら画面案内に従う。生成projectを再生成するとTeam設定が失われ得るため、実機設定は最後に行う。

既存の記事配信が変わっていなければVault再同期・Pages再公開は不要。記事取得失敗の場合だけWindows側で`npm run app:verify -- https://maruyamamasaya.github.io/studyApp/`を確認する。

## 4. 実機で先に通す5ケース

失敗したら同じ条件を繰り返す前に、下表の状態とエラーを記録する。全機能の組合せ総当たりは夜の初回には行わない。

| 優先順 | 操作 | 合格条件 |
| --- | --- | --- |
| 1: iCloud / 再起動 / オフライン | ダウンロード済みフォルダを設定→2音声・台本・番組確認→Aを10秒以上再生し一時停止→アプリ終了・再起動→機内モードで保存音声を再生 | articleIDで対応、二重登録なし、bookmark再指定なしで復元。同期エラーでも旧音声が残りコピーを再生できる。位置は一時停止位置付近 |
| 2: ロック中の連続再生 | 番組を「最初から」、3秒間隔・BGM ONでロック→B→間隔→A→終了。ロック画面でpause/playと前/次。続けて0秒間隔・BGM OFFを1周 | 配列順、3秒間隔でも進行、BGMは間隔中継続・pause/終了で停止。0秒/BGM OFFでも次へ進む。終了後ループなし |
| 3: 番組途中再開 | ナレーション途中でpause→終了・再起動→「続きから」。次は10秒間隔で途中pause→終了・再起動→「続きから」 | 同じ番組・トラック順・位置、間隔は残り秒数から復帰。前/次で先頭位置。速度変更はナレーションのみ |
| 4: 同期と差し替え | 再生中のトラックと同じID・別音声を同期。続いて変更なし同期、不足trackIDの番組同期。順番をA→Bへ変更して途中再開と「最初から」を比較 | 差し替えで停止しID維持・位置0、新音声再生。変更なしは位置維持。不正同期で旧一覧・音声維持。途中再開は旧順、最初からは新順 |
| 5: 割り込み / 権限 | ナレーション中と間隔中でイヤホン切断（可能なら着信も）→手動再開。フォルダ移動等でbookmark復元を失敗させ再指定。未ダウンロードファイルの同期、選択キャンセル | ナレーション・BGM・間隔進行が止まり自動再開なし。旧音声を失わず権限を再設定可能。未DLは成功または明示エラー＋旧データ保持、キャンセルで既存設定維持 |

特にケース4は、radioの再開位置とトラック個別位置が別に保存される経路を確認する。コードの静的レビューだけでは再生中差し替え後の実際の位置を保証しない。ケース2/3/4の失敗は連続再生を日常利用する前に解決する。

余裕がある場合: 10秒間隔完走、ロック画面15秒・シーク、BGM音量、台本/titleのみ更新、article hash差表示、学習時間と読了が増えないこと。通常セットで成功してから行う。

## 5. 結果記録

SHA / Xcode・iOS版 / Simulator id / build結果 / XCTest実行数・失敗数 / 実機1〜5のPass・Fail・未実施 / 失敗時のトラックID・番組phase・位置・BGM・画面状態をsessionへ記載。未実施は合格にしない。
