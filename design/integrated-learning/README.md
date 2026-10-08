# Study App 統合学習機能設計
更新: 2026-10-08 / 状態: 全体設計提案、iOS部分の実装を追加（未検証） / 調査基準: e1b201e

初回の成果物は調査・要件・基本設計・詳細設計の検討。その後のユーザー依頼でiOS部分を実装した。全体設計の「提案」はすべて採用済みではない。数値目標も受入条件の案であり、測定済み性能ではない。iOSの対応範囲・代替方式・未検証事項は[iOS実装記録](../../ios/VISUAL_RESOURCES.md)と[ADR-018](../../decisions/ADR-018-ios-local-visual-resources.md)を参照する。Web実装と公開添付同期は今回変更していない。

## 文書と責務

| 文書 | 扱う内容 |
| --- | --- |
| [01 構成調査](01-current-system.md) | 一次情報、現行機能、重複と不足 |
| [02 機能要件](02-functional-requirements.md) | 機能ID、範囲、受入条件 |
| [03 非機能要件](03-nonfunctional-requirements.md) | 性能・容量・運用・アクセシビリティ |
| [04 基本設計](04-system-design.md) | コンポーネントとデータフロー |
| [05 データ管理](05-data-design.md) | ID・索引・関連・版管理 |
| [06 UI・UX](06-ui-ux.md) | WebとLearnleafの導線、状態 |
| [07 変換・閲覧比較](07-conversion-viewing.md) | 入出力の忠実度、変換処理 |
| [08 技術選定](08-technology-options.md) | OSS・ライセンス・導入負荷・確認事項 |
| [09 セキュリティ](09-security.md) | 信頼境界、SVG・Office・PDF |
| [10 実装計画](10-implementation-plan.md) | 依存関係、検証、判断事項 |

## 現在のデータの所在

記事の正本はObsidian Vault。GitHub PagesはMarkdownと一覧JSONの配信場所。LearnleafはWebページを包むアプリではなくSwiftUIの独立した閲覧アプリで、共通の配信記事を取得する。Webの学習状態はブラウザー、Learnleafの学習記録・テーマ・保存記事は端末側にある。共通のサーバーDBや自動記録同期はない。

## 推奨案

記事の配信v1を維持し、添付ファイルと版付きリソース索引を追加する。Office原本からローカルで閲覧用PDF・検索用テキストを生成し、WebとiOSで再利用する。図解とプレゼンテーションは同じリソースIDで記事と関連付ける。AIは後から生成候補を提示し、基本閲覧には不要とする。

既存ADR-005/006/008/009/017と整合する提案であり、まだ採用判断を置き換えない。今回新しいaccepted ADRは作らない。公開資料と端末内だけの資料の境界、iOSのSVG表示方式、変換環境、上限値、編集の主端末は実装前に判断する。
