# Living Auroraの全テーマ

## 依頼と調査

ユーザーがLiving AuroraのテーマをすべてLearnleafで選べるよう依頼。元repositoryの`src/design-system/themes/index.ts`、`src/styles/themes.css`、`src/styles/windows-98.css`、`ios/DesignSystem/Theme.swift`を確認。Web側にはLiving Aurora / Pulse Neon / Blue Cosmos / Windows 98の4種があり、元iOS側は3種。前回Learnleafは配色固定で切替・星空は未実装だった。

## 実装

- `StudyTheme`に4テーマの名前・配色・形状を定義し、SwiftUI Environmentで全画面へ渡す。設定→テーマに各テーマのプレビューと選択状態。AppStorageに選択を保存し、変更は現在の画面へ即時反映する。画面・再生状態をリセットしない。
- Blue Cosmosは固定seedの240星と局所光、Pulse Neonは回路グリッドとシグナル、Living Auroraは紫/シアンの局所光、Windows 98は青緑背景・灰色面・角のある立体枠。iOSの標準操作は維持。常時アニメーションは前回合意どおり導入しない。
- カード、タグ、リンク、見出し線、引用、コード、表、ミニプレイヤー、List/Formの行・背景へテーマを適用。本文は読みやすい単色面。選択・編集sheetにもEnvironmentを継承。
- 表示モードは端末に合わせる/ライト/ダークを別保存。Windows 98は明るい固定表示を使用。テーマと表示設定は学習記録backupの対象外。
- 既存の未commit変更と並行作業による差分を保持。実機インストール・commit/pushは実施しない。

## 検証

- XcodeGen生成成功、Simulatorビルド成功。
- XCTestは最終操作調整後に41件成功。追加2件は全テーマの保存値復元/未知値fallbackと、明暗でのリンク・ボタン文字の4.5:1以上のコントラストを確認。
- 既存iPhone 17 `757967D4-AED3-41C8-8910-D6E1FDE398E6` 1台、並列無効。初回/最終ともXCTest device setは前後18台、新規IDなし。今回作成の複製0、削除0。実行後プロセス記録も保存。
- 実行ログ・コマンドを含むbuild/test log、実行日時、端末JSON、プロセス記録: `/tmp/learnleaf-themes-verification/`。DerivedDataは`/tmp/learnleaf-themes-build/`。
- Simulatorでテーマ設定入口、4種のプレビュー、Blue Cosmos選択の即時反映とアプリ再起動後の維持、ライト/ダークの星空ホーム、Pulse Neon選択と回路背景、カード全域での選択を確認。
- `python3 build_note_index.py`成功、両索引の差分なし。`git status`/`git diff`/`git diff --check`確認済み。
- Windows 98のプレビューを確認。最終版でのWindows 98全画面操作、音声を持つ状態の再生バー/再生画面、本文リンク、アクセシビリティ設定別の実表示は未確認。

## 残課題

実機反映は未実施。実機で全テーマの評価・操作確認、大きな文字/VoiceOver/Reduce Transparency/Increase Contrastでの表示確認を行う。標準iOSのタブ・入力部品はプラットフォームの形を維持し、Windows UIそのものには置換しない。
