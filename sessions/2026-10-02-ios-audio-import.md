# 事前生成音声の受け入れ

依頼: アプリのみ修正し、iCloudのダウンロード済み音声を受け入れる。trackIDと制作ツールの方向を検討する。

変更: AudioLibrary/AudioView/TrackPlayerを追加。「聴く」タブ、記事からの入口、手動紐付け、管理JSON+音声+台本、trackID重複拒否、元記事hash差の表示、端末内コピー、再生/一時停止/シーク/倍速/BGM/位置保存、ロック画面/バックグラウンド/割り込み対応。Info.plistはXcodeGenのinfo定義から生成する。

制作側は今回実装せず、UUIDのtrackIDと既存articleIDを持つ出力契約をios/AUDIO_IMPORT.mdに記録。初期CLIと後のデスクトップUIを候補として整理した。外部ファイル原本、Web、Vaultは変更していない。

検証: 6件の音声XCTestを追加したがWindowsでは未実行。Macで合計13件のXCTestと実機確認を行う。Windowsでは既存Nodeテスト20件成功、索引生成後の2索引に差分なし、diff check成功。YAML形式とUTF-8/末尾空白を静的確認する。これらはSwiftの型検査・実機動作を確認するものではない。

残課題: Macの依存解決・ビルド・テスト、iCloud File Providerとロック画面/割り込み実機動作、制作ツール、削除UI・音声一覧export・連続再生。音声聴取を読書時間に合算しない。今回の変更はcommit/pushしていない。
