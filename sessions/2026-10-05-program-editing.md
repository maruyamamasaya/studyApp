# Learnleaf番組の個人編集

## 調査・実装

AGENTS/CURRENT/ARCHITECTURE、ADR-012/013、AudioLibrary/RadioSession/TrackPlayer/AudioViewと音声テスト、関連Git履歴を確認。既存の未commit変更（StudyAppの再生バー配置、CURRENT/ARCHITECTURE、reader-player-layout session）は保持。

番組タブで作成・名前変更・削除、取り込み済み音声の複数選択追加・解除、編集モードのドラッグによる再生順/一覧順変更を実装。削除確認は音声と再開状態の保持を説明する。空番組を保存でき、空の新規再生を防ぐ。

index v1のoptional editedProgramIDs/deletedProgramIDsで個人編集を再同期より優先。削除の再取り込みを抑止し、追加番組は一覧末尾へ配置。編集はatomic保存成功後のみ画面へ反映。保存エラーは既存の音声アラートへ表示。音声ファイル・位置・聴取済み、現在のRadioSessionを変更しない。途中再開では既存スナップショット、最初からでは編集済み番組を使う。ADR-015、CURRENT/ARCHITECTURE、RADIO_PLAYBACKを更新。

## 検証

- Xcode Simulatorビルドと全37件XCTest成功（既存35件＋番組編集2件）。再起動・再同期、名前/順番、削除復活防止、空番組、ファイル/位置/聴取済み/曲間と区間再開の保持、無効編集のatomic性を確認。
- コマンド: xcodebuild -project ios/StudyApp.xcodeproj -scheme StudyApp -destination 'platform=iOS Simulator,id=F26F773A-A316-4610-9228-84217FEEB82A' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -derivedDataPath /tmp/learnleaf-program-build test
- 記録: /tmp/learnleaf-program-tests/ のbefore.json、after.json、time.txt、processes-before.txt、processes-after.txt、test.log。終了コード0、xcodebuild/xctest/runner終了を確認。XCTestDevicesは前後とも18台Shutdown、追加IDなし。今回の複製0、削除0、今回の残存0。他作業の18台は変更せず。
- sandbox内の初回simctlはサービス接続/ログ権限に失敗。承認されたsandbox外実行で取得・テスト・前後記録成功。
- python3 build_note_index.py成功、docsの索引2ファイル差分なし。git diff --check成功。
- lint/typecheckの専用設定なし。Swiftコンパイルは上記ビルドで確認。

## 残課題

ユーザーの追加依頼により、既存Teamで実機ビルド成功。Vesperaへ同じbundle IDで上書きインストール・起動成功（2026-10-05）。ビルドログは /tmp/learnleaf-program-tests/device-build.log。実機でのドラッグ/複数追加、再生中編集の聴感、バックグラウンド操作は手動確認が残る。番組個人編集は学習記録バックアップに含まれない。制作側優先に戻すリセットや複数端末間同期は今回の対象外。
