# 統合学習機能の設計

## 調査と成果

ユーザー依頼でSVG図解、Markdownからのプレゼンテーション、Office/PDF資料閲覧をStudy Appへ統合する設計のみ実施。AGENTS/CURRENT/ARCHITECTURE、関連ADR、配信契約、Node同期/索引、Web入口/reader、SwiftUIの閲覧/検索/記録/offlineコード、e1b201eまでの履歴を確認した。記事正本はVault、Web/iOSは共通HTTPS配信、個人記録は別保存と確認。

[設計書索引](../design/integrated-learning/README.md)から10本の調査・要件・基本/詳細設計検討文書へ相互参照。公式OSS資料でライセンス、機能範囲、PDF.jsのadvisory等を調査した。候補の実機性能、Office忠実度、採用版の全依存監査は未実施と明記。

## 検証

- npm test: 24件成功。
- python3はPATHにないため既存bundled Pythonでbuild_note_index.pyを実行。docs/_note-index.jsonとdocs/_article-master.jsonの差分なし、既存ID維持。
- 新設計書のローカルMarkdownリンクとコードfence、変更範囲を確認。git diff --check成功。
- 設計文書のみのためアプリコード/依存変更、iOSビルド/Simulator実行、Vault同期/公開記事更新は行わない。

## 判断と残課題

設計案は未採用で新accepted ADRを作らず、ARCHITECTUREの現行説明も変更しない。CURRENTへ構想と未決定事項の入口を追加。公開/private境界、制作主端末、iOS SVG/slide viewer、Office converter/フォント、容量・性能、AI送信条件は実装前に決める。既存同期不整合は別の課題記録として維持。ユーザーの明示依頼に従い設計文書と課題記録をcommit/pushする。
