# 10. 段階的実装計画書
状態: 将来計画。今回は設計書完成で終了する。

## 依存順の推奨計画

| 段階 | 主な成果 | 対応要件 | 完了ゲート |
| --- | --- | --- | --- |
| 0 基盤・判断 | 公開/private境界、資産schema、ID/path/hash、既存同期課題を別途解消 | F11/16基盤 | v1互換、既存ID維持、公開対象検証、docs上書き保護 |
| 1 安全なSVG | 添付同期・静止SVG/PNG・記事埋め込み・拡縮/全画面 | F01/02 | Web root/training、iOSで明暗/pinch/代替操作、悪性SVG |
| 2 図解ライブラリと関連 | metadata/thumb/tag/search、article/resourceリンク | F03/05 | 共用再利用、移動/更新/削除/要素参照の検証 |
| 3a PDF | 原本import、PDF viewer、text/scan区別、local保存 | F11/14 | large PDF・通信断・quota・検索・ページ対応 |
| 3b Office | PC変換pipeline、DOCX/PPTX原本、PDF/text/notes派生 | F12/13/15 | font/表/図形/notes/旧format/失敗/取消、外部通信なし |
| 4 発表表示 | 保存deck表示、swipe/key/notes、図解拡大 | F09 | PC/iPhone/iPad、縦横/全画面拒否/notes漏えい防止 |
| 5 slide草稿と編集 | 見出し分割・固有内容・分割結合順序・更新差分 | F06/07/08 | 手動編集保持、元記事削除・再生成競合 |
| 6 export | SVG/PNG/ZIP図解、PDF/HTML deck、後続PPTX/SVG slide | F04/10 | 出力再読、font/資産/notes/ライセンス欠落なし |
| 7 AI/RAG | 明示承認付き候補生成・横断検索 | F17 | AIなし基本利用、根拠参照、機密/競合/権限の検証 |

元のPhase7「相互リンク」は再利用・更新整合性の前提なので段階2へ繰り上げる。PDFとOffice変換を分け、SVG資産同期を先行させる。PPTX出力と既存PPTX閲覧を別段階にする。見積もり日数はconverter/端末評価前には確定しない。

## 実装前の判断一覧

| 項目 | 推奨初期案 | 未確定な理由 |
| --- | --- | --- |
| 公開/私的資料 | Vault private originalは公開Gitへ入れない、端末importは私的 | 利用する資料の公開可否が未提示 |
| 制作主端末 | PC編集/変換、iOSは閲覧中心 | スマホでのフル編集の必須度 |
| Office PDF変換 | ローカルLibreOffice | 導入package license、font、サンプル忠実度 |
| iOS SVG/slide | PNG/PDF代替、限定WebViewはPoC比較 | native表示と従来script方針の整合 |
| 取り込み共有 | 書き出し→Vault→明示公開 | 自動同期/非公開backendは未設計 |
| サイズ/性能 | 03の目標値 | 実機測定未実施 |
| 更新/削除 | ID維持、差分確認、旧版保持 | 保持期間/容量policy |
| AI送信 | 初期なし、本人承認後のみ | provider/費用/機密条件未指定 |

これらは作業を止めるための承認要求ではなく、将来実装開始時の判断事項。設計の中では提案として残す。

## 検証計画

各段階は既存npm testと必要な対象fixture（schema/path/hash、import/悪性入力、参照整合性、deck差分）を実行。Web挙動変更時はローカルHTTPでroot/trainingを確認。iOSテストはios/READMEのSimulatorルールに従い、既存1台・並列なし・実行前後記録・自分の複製だけ清掃。最終変更後に必要な全体テストを1回、性能問題や失敗時だけ追加する。

WindowsでiOS合格を宣言しない。公開機能変更時は生成差分と公開HTTP/hashとActionsを確認し、push成功だけを公開成功とは扱わない。

## 今回の完了条件と残課題

10本の文書と索引、相互リンク、既存一次情報、OSS根拠をレビューし、Markdown追加に伴う既存索引再生成の差分を確認。設計文書のみGit管理してcommit/pushする。アプリ本体・依存・公開記事・Vaultを変更しない。既存同期不整合は課題として保持、公開作業と一緒に修正しない。

将来正式採用した判断のみ新ADRへ記録する。現行ARCHITECTUREは実装構成を示すため新構想へ置き換えない。
