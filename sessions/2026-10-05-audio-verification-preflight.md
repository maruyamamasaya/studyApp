# 音声機能の検証事前整理

- 対象mainは2a9fbdffff87074bf22b1351aca29964adb0e938。
- AGENTS、CURRENT、ARCHITECTURE、ADR-011/012/013、iosの全ソース・テスト・仕様を静的レビュー。
- XCTestは7+10+6=23件。明白なcompile/test failureは見つからず、アプリコードは変更しない。
- ios/MAC_AUDIO_VERIFICATION.mdに日中と夜の切り分け、サンプル準備、5つの優先実機ケース、結果記録を整理。
- ios/scripts/verify-mac.shで生成→依存解決→build-for-testing→23 XCTestの手順を固定。Mac未実行。実行結果は後で記録する。
- VOICEVOX制作ツールの実装は行わない。OS依存挙動は未検証のまま。
- Linuxでnpm ci、npm test（20件成功）、unique-heading-ids、bash -n、索引再生成（生成差分なし）、git diff --checkを実施。これはiOSビルド成功の証拠ではない。
