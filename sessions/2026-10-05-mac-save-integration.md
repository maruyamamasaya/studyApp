# Mac保存変更と最新mainの統合

- 最新mainの匿名化・記事追加・自由なtype対応を保持し、保存済みLearnleafの探索・履歴・音声UIを通常mergeで統合。CURRENT.mdは両方の記録を保持。
- 公開取込記録JSONのsource欄を既存記事と同じF社表記に匿名化。記事ID、移行先、originalHashは変更しない。公開session Markdown/JSONの既知の実名残存を限定点検し、残存なし。
- 検証: Web23テスト、既存iPhone 17 Pro SimulatorでiOS36テスト成功。Applied/development-log/空type、履歴保存・復元、音声取り込み・差し替え・再開・聴取済み状態を既存回帰テストで確認。索引再生成の差分なし、diff check成功。依存は既存キャッシュを使用。
- Simulator実行は直列。XCTestDevicesは前後18件、新規複製・削除は0件。今回の記録は/tmp/study-final-ios-qa/に保存。既存端末は削除しない。
- 実機への更新、実iCloudファイル、ロック中再生、割込み、実データの途中再開は、この統合の自動テストだけでは確認済みにしない。
- 履歴書換え・force push・手動Pagesリリース・公開設定変更は行わない。元のcheckoutは保持。
