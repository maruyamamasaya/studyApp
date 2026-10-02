# iOS初期実装

ユーザー承認: Windowsで実装を進め、Xcodeのビルドとテストは帰宅後のMacで行う。

既存構想、v1配信契約、ADR-008/009、現在の同期実装・Git履歴を確認。ios配下にSwiftUIの一覧・本文・リンク・読了・計測・履歴・設定・JSONバックアップ、HTTPSクライアント、Schema検証と本文hash照合を追加した。記録は版付きJSONのatomic保存。Web・Vault原本は変更していない。

XcodeGen定義と7件のXCTestを追加。Macでの生成、署名、ビルド、テスト、手動確認手順はios/README.md。SwiftツールチェーンがないためXCTest、型検査、Simulator動作は未実行。Windowsではnpm testの20件が成功、索引生成後の2索引に差分なし、変更対象のdiff check成功、XcodeGen YAMLのparse成功を確認。生成したXcode projectの検証を意味するものではない。

残課題: 配信JSONの公開確認、Macの依存解決・ビルド・テスト・実機導入。見出しスクロール、日別集計・日付またぎ配分、画像・添付は未実装。現段階で初期版の全完了条件を満たしたとは扱わない。commit/pushは行っていない。
