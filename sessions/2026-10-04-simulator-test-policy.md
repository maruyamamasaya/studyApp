# iOS Simulatorテスト運用の文書化

- 調査: AGENTS.md、CURRENT.md、ARCHITECTURE.md、ADR-010、ios/README.mdと関連Git履歴を確認。既存の未コミット変更を保持。
- 変更: AGENTS.mdからios/README.mdの運用ルールを参照。単体・回帰・UIテストの端末再利用、通常の並列無効化、例外時worker最大2、実行前後の記録、所有と停止状態の確認、終了後・中断後の清掃、削除確認と報告、全体テストの反復抑制を記載。
- 検証: 文書差分とgit diff --checkを確認。Markdown追加に伴う索引生成を実施し、既存IDと索引に差分がないことを確認。ユーザー指定によりテスト実行・Simulator操作・端末削除は行わない。
- 判断: アプリ構成・データフロー・現在の機能状態は変わらないためCURRENT.md、ARCHITECTURE.md、ADRの追加更新は不要。
- 残課題: 本依頼に未解決事項なし。自動清掃スクリプトは実装しない。
