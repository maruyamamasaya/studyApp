# 記事末尾と再生バーの配置

- 調査: CURRENT/ARCHITECTURE、ADR-010、StudyApp/AudioViewとGit履歴を確認。全タブでNavigationStackの外側にsafeAreaInsetを置く既存構成。ユーザーから記事末尾の「読了として記録」が再生バーに隠れるとの報告。
- 実装: 共通PlayerTabContentでNavigationStackとAudioMiniPlayerをVStackの別領域へ配置。再生バーは実際の高さを保持し、画面に残りの高さを渡す。固定の補正値を使わず、音声未選択時はバーの領域を作らない。読了・計測・音声の保存処理は変更なし。
- 検証: iPhone 17e既存Simulator UDID EB3A49ED-6553-4D7E-B933-387951643EAB向けxcodebuild build成功。DerivedData: /private/tmp/learnleaf-player-layout、ログ: /private/tmp/learnleaf-player-layout-build.log。XCTest/Simulator起動は実行していないためテスト用複製の作成・清掃なし。npm test 20件成功。索引再生成で生成物差分なし。git diff --check成功。
- 残課題: 再生中の記事末尾、文字拡大、フォルダ経由の本文について画面の手動確認は未実施。実機へのインストール・公開は未実施。
