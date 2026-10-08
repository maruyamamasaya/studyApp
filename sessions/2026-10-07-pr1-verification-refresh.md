# PR #1のMac検証手順を現行mainへ整理

- 対象main: e1b201e。PR #1の5ファイルを比較し、古いSHA・23件未実行の記録と重複する音声実機チェックリストは採用しない。現在の実機項目はios/AUDIO_IMPORT.md・RADIO_PLAYBACK.mdを参照する。
- mainに実行スクリプトはないため、生成→依存解決→build-for-testing→test-without-buildingを残す。StudyAppTests全体を既定とし、対象指定も可能。件数を固定しない。
- 並列無効・destination最大1、SHA/未commit状態/Xcode/端末/コマンド/ログ/xcresult、成功・失敗時の前後記録を追加。自動端末削除は行わない。子プロセス終了・所有確認はREADMEの運用に従う。
- 旧PR headをours mergeで祖先に保持し、current mainを基礎に最小差分を作成。force push不要。CURRENT/ARCHITECTUREに状態・構成の変更はない。
- 検証: bash -n成功、引数なしは案内とexit 2。実スクリプトでXcode 26.6、iOS 26.5の既存iPhone 17 Pro（F26F773A-A316-4610-9228-84217FEEB82A）1台を使用。生成・依存解決・ビルド成功、xcresultは51件成功/失敗0/skip0。
- 実行記録: /var/folders/91/r9h2q_ys771bmhhb_x9z46gw0000gn/T/studyapp-verification.JPcVAt。実行前に他のxcodebuild/xctestなし、終了後も関連プロセスなし。前後のXCTestDevices JSON取得成功、新規ID0、削除0。今回の複製はない。
- 最初のsandbox内呼出しは/dev/fdへのアクセス制限でビルド前に停止。権限付きで上記実行を完了した。
- 索引再生成の差分なし、git diff --check成功。アプリコード/記事は変更なし。実機音声の手動確認は今回未実施で、既存の残課題を継続する。
