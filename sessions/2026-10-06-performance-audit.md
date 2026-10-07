# Learnleaf性能調査

ユーザーの実機での重さの報告に基づく調査。アプリコード・実機配布物は変更しない。

## 根拠と測定条件

CURRENT/ARCHITECTURE、ADR-012、UI刷新session、現行ソースとGit履歴を確認。測定スクリプトと結果は `/tmp/learnleaf-performance/`。381記事の既存公開catalogスナップショット、実際のStudyAudio（50音声・10番組・参照160ファイル・148,125,104 bytes）を使用した。元音声は読取のみ、importTracksはUUID付き一時フォルダへ実行。

Swiftの単独プログラムで計算部分を測定した。ピックアップは既存ArticleDiscoveryをそのまま抽出、検索は現行の計算構造を再現（本文走査とSwiftUI描画を含めない）。ピックアップ/検索は配布中のDebug相当の-Onone、音声は-O。Mac上の測定でありiPhoneの処理時間やフレーム時間とは同一視しない。ピックアップ/検索は20回の中央値、音声は1回の参考値。

実機Time Profilerは `xcrun xctrace record --template 'Time Profiler' --device Vespera --attach StudyApp --time-limit 15s` を試行したが、端末接続待ちでタイムアウト（終了13）。有効な実機traceは得られていない。sandbox内のInstruments/音声読取は権限制限に失敗し、承認された外側実行で測定した。

## 優先度1: ホームのピックアップ

LibraryViews.swiftのArticleDiscovery.picksはsortedの比較ごとに2件のSHA-256とhex文字列を生成する。381件の選出中央値462.22ms、最大554.70ms。ArticleList.body内で直接呼び出すため、ホームの再評価時に同じ計算を繰り返し得る。Library.excerptsはObservableObject全体を通知するため、抜粋取得完了も再評価要因になる。

一時的な比較実装で各記事のhashを1回ずつ事前計算すると中央値16.82ms、最大17.24ms。同じ3記事・順番になることをassertで確認。計算部分で約27倍の差。製品の体感速度が27倍になるという意味ではない。

対策候補: hashの事前計算、結果を記事集合/日付/入れ替え回数単位で保持し、View.bodyから高負荷計算を除く。日替わり・手動入れ替え・記事更新時の選出規則を維持。

## 優先度2: 音声同期のUI停止と一時メモリ

AudioLibraryModelは@MainActor。refreshのreadFolderのみTask.detachedで、その後のstorage.importTracksはメイン側。importTracksは変更のない音声も全AVAudioPlayer検証とSHA-256計算を行う。readFolderは参照音声をData配列にすべて読み込む。

実データの参考値: readFolder 0.528s、初回importTracks 0.181s（60件更新）、変更なしimportTracks 0.080s（0件更新）。この0.080sは音声ファイルが変わらなくてもUI側で同期実行される処理。-OのMac測定でも約80msだが、実機での停止時間は未測定。参照Dataは約148MBあり、これは全RSSやピークメモリの測定値ではない。

起動時とscenePhaseのactive復帰で同期するため、フォルダを設定した端末だけ起動/復帰が重くなる可能性。対策候補: 取り込みを専用の直列処理へ分離し、UI側は状態反映のみ。差分確認/ストリーム読取で同一音声の繰り返し全検証とData保持を減らす。hash照合・原本保護・atomic保存を維持し、storageに単純な並列アクセスを導入しない。

## 優先度3: 検索計算と再描画

SearchViewのarticles/tracks/programsはcomputed property。各結果はcount/isEmpty/見出し/ForEachで約4回計算される。articleIDを毎回firstで走査し、音声有無条件ではarticleごとに全音声のSetを作る。番組も音声全走査とcontainsを繰り返す。

現在の計算構造を4回ずつ評価した参考値（20回中央値、本文なし）:

| 検索語 | 音声あり条件なし | 音声あり条件あり |
| --- | ---: | ---: |
| 空 | 6.58ms | 36.47ms |
| RAG | 16.48ms | 43.69ms |
| 存在しないキーワード | 24.61ms | 51.16ms |

実際の1回のSwiftUI更新時間の計測値ではない。入力変更ごとにメイン側で計算され、debounceはない。全文検索中は1記事ごとにStateを更新し、それまで取得した本文も毎回検索する。Library側とSearchView側に本文を保持し、永続索引・サイズ制限・旧hashの除去はない。

TrackPlayerは1秒ごとにpositionをPublished更新し、停止中もnarrationが残っていれば同じ値を設定する。検索・聴く画面はTrackPlayerを購読するため再評価要因。再生中は5秒ごとに音声indexのatomic保存/Published更新もあり、番組再生では位置と番組の保存を別々に行う。

対策候補: データ更新時にID辞書/音声ID Set/番組構成を作り、検索結果を1回計算して使い回す。入力を短くdebounceし、計算をUIから分離。全文検索結果と進捗通知をまとめる。再生進捗を必要な部品だけが購読し、停止中の同値通知を抑える。

## 補助的な候補

- ListeningHomeはScrollView内VStackで音声全件を構築する。50音声へ増加したのでLazyVStack等で画面外の構築を減らす。
- ArticleLinks.bodyは行ごとにNSRegularExpressionを生成し、本文/抜粋/全文検索の変換で繰り返す。抽出自体もメイン側で実行される。
- 抜粋はカード表示のたび本文HTTPS取得が必要（メモリcacheには再利用あり）。再起動時にキャッシュを失う。全文検索は対象本文を直列取得するため初回に待ち時間がある。
- テーマは静的gradientで、常時アニメーションやbackdrop blurを導入していない。現時点では装飾を主原因と断定する根拠はない。GPU/フレームの実機計測は未実施。

## 次の確認・作業

まずピックアップの事前計算/結果保持、次に音声同期のUIスレッドからの分離、検索結果/再生購読の整理を推奨。改善前後の計算結果一致と起動/タブ切替/スクロール/再生中検索を確認する。実機Instruments、全文検索中のRSS/CPU、音声同期中のUI停止は未測定。ユーザーへ重い場面を質問済みで、この調査時点では回答未取得。

検証: 計測スクリプトのcompileと実データ実行、ピックアップ比較結果一致、git diff --check。アプリソースは変更していないためSimulator全体テストと再配布は行わない。索引再生成の差分を確認する。
