# 番組の連続再生と音声機能のリモート反映

依頼: 再生順・インターバル・途中再開を実装し、Macでまとめてテストする。音声機能を一式commit/pushする。

変更: playlistID/trackIDs/gapSecondsの番組契約、*.playlist.json同期、全入力検証、番組/再開状態の保存、ナレーション→無音PCMインターバル→次トラックの遷移、終了時のBGM停止、前/次操作、番組別間隔設定を追加。直前の音声取り込み・自動紐付け・差し替えも今回のリモート反映対象。

Mac用XCTestは既存7件+音声保存10件+番組状態6件の合計23件。ユーザー方針に従いWindowsではSwiftビルド・XCTest・実機動作は未実行。Windowsで既存Node20テスト成功、YAML parseとBackground Audio設定、UTF-8/末尾空白、diff check、索引再生成後の差分なしを確認。Mac手順をios/RADIO_PLAYBACK.mdへ記載した。

残課題: Macでの型検査/ビルド/23件XCTest、iCloud bookmarkとバックグラウンド/割り込み/再生中更新の実機確認、制作ツール。複数番組ごとの再開状態、音声削除UI、旧コピーの容量管理、聴取時間集計は初期版に含めない。今回の変更はユーザー依頼によりcommit/pushする。
