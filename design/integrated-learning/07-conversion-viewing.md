# 7. ファイル変換・閲覧方式比較書
状態: 推奨案。実ファイルの変換検証は未実施。

## 形式別の扱い

| 形式 | 推奨閲覧方式 | 学習用抽出 | 制限/代替 |
| --- | --- | --- | --- |
| SVG | 安全化SVG、iOSは限定viewerかPNG派生 | title/desc/要素関連metadata | script/外部参照禁止、複雑filterはPNG代替、動作は静止化 |
| DOCX | ローカルLibreOffice等でPDF派生、必要ならdocx-preview試験 | Mammothで構造HTML→sanitize→Markdown候補 | font/段組/改ページ/図形の完全再現は保証しない |
| PPTX | PDFページ+thumbで共通閲覧 | converter/検証済みOOXML parserでtext/notes抽出 | 動画/animationは静止、SmartArt/特殊fontは要サンプル評価 |
| PDF | Web PDF.js、iOS PDFKit候補 | text layerとpage対応 | scanはOCR別、暗号化は明示拒否か対応後、埋込script実行しない |
| XLSX | SheetJS候補で値/範囲、必要時PDF | cell値+sheet+range | 数式再計算/マクロ/Officeの完全レイアウト再現は対象外 |
| DOC/PPT | PCでローカル変換しDOCX/PPTX/PDFへ | 変換後の抽出 | 旧formatの直接実装を避け、原本と変換ログを保持 |

DOCXのレイアウト閲覧と構造抽出を別のroleにする。Mammothは文書の意味構造をHTMLへ写す設計であり、Wordの見た目を複製する用途ではない。[公式README](https://github.com/mwilliamson/mammoth.js)

PPTX閲覧とPPTX生成を混同しない。PptxGenJSは新しいpresentationを生成する候補で、既存PPTXの読み込みエンジンとして採用しない。[公式repository](https://github.com/gitbrent/PptxGenJS)

## 変換場所の比較

| 場所 | 長所 | 費用/制限 | 判断 |
| --- | --- | --- | --- |
| ブラウザー内 | 外部送信不要、Files/drop対応 | memory/quota、font/Office再現性、重い変換 | 小型DOCX構造抽出/PDF閲覧を優先 |
| PCローカル | font/LibreOffice/worker制限を管理、結果を端末間共有 | セットアップ、環境差、重いjob | Office→PDFの初期推奨 |
| iOS端末 | private資料が端末に留まる | OSS JS依存はnativeから直接使えない、OSの背景制限 | PDF閲覧/Files importを優先、Office重変換は後続 |
| 自前server | 端末負荷を軽くできる | 認証/保存/機密/運用費と新backend | 初期採用しない |
| 外部Office viewer | 高い再現性を期待できる | 外部送信、公開URL、通信依存 | 既定にしない |

## 変換jobの詳細案

原本をstagingへコピー→拡張子/実体/size/ZIP/XML/暗号化検証→raw hash→重複通知→job作成→ネット遮断した制限processで変換→派生の実体/size/hash/参照/抽出text検証→metadataにconverter版/profile/warnings保存→原本/派生の確定→公開は別の明示操作。

jobはqueued/running/succeeded/partial/failed/cancelled。入力hashが変わればobsolete扱い。timeout/取消後はprocess tree停止を確認し自分のtempだけ清掃。原本の登録と派生成功は別の状態で、原本保存成功時には変換失敗でも失わない。検証で危険判定なら隔離/拒否。公開は成功済み派生だけ、旧版は保持。

OOXMLのメタデータはtitle/author/date候補を抽出するが、公開前に本人情報を確認する。notes/コメント/変更履歴/埋込ファイルは公開デフォルトから除外。画像抽出はURLではなく検証済みbytesとして登録する。scan PDF OCRはlanguage/engine/confidenceとpage対応を保持し、誤読を原文へ自動確定しない。

## エクスポート比較

| 形式 | 編集性 | 再現性 | 難度案 | 方法/制限 |
| --- | --- | --- | --- | --- |
| PDF | 低 | 高め | 中 | browser print/ローカル印刷。font・余白・notes除外を確認 |
| PPTX | 高（text/shapeの場合） | 中 | 高 | deck model→PptxGenJS。図解は画像化fallback、HTML完全再現不可 |
| HTML | 高（source編集） | browser依存 | 中 | Reveal+資産package、scriptはviewer自身のみ、offline依存を同梱 |
| SVG | vector部品の編集可 | 中 | 高 | 管理されたslide layoutから静止vectorへ。任意HTMLの変換は保証しない |
| PNG | 低 | 見た目を固定 | 中 | 指定解像度でraster、透明/背景/文字欠落を評価 |

RevealのPDFはprint工程であり万能なPPTX出力ではない。[PDF export](https://revealjs.com/pdf-export/)。
slideのSVG/PNGと図解original exportを別操作にする。ZIPは必要ファイル・manifest・LICENSEを含め、private notes/originalは既定除外、依存欠落を検証する。
