# 8. 技術選定・ライブラリ比較書
調査: 2026-10-08。採用候補であり依存追加なし。公式README/License/配布案内を確認した。latest版番号や最終commit日は固定せず、導入時のrelease・advisory・対応OS検証を採用ゲートとする。

## 比較

| 技術 | ライセンス/公式根拠 | 維持・安全性の評価 | モバイル/負荷 | 推奨 |
| --- | --- | --- | --- | --- |
| Docsify/MarkdownUI | 現行実装を継続、導入済み版のLICENSE確認は更新時 | 記事描画と内部リンクが実装済み、JS/CSS共有を維持 | 現行スマホ/SwiftUI対応 | 再利用 |
| ブラウザーSVG | Web標準、追加runtime不要 | 安全化/外部参照禁止は別途必要 | iOS nativeのSVG保証とは別 | Web第一候補 |
| DOMPurify | Apache-2.0またはMPL-2.0 [公式](https://github.com/cure53/DOMPurify) | 既存版をそのまま安全と断定しない。拡張policyと更新評価必要 | SVG/HTMLをsanitize、worker単独ではDOM環境がない | 既存再利用+policy分離 |
| Reveal.js | MIT [公式](https://github.com/hakimel/reveal.js) | Markdown/notes/printの公式機能あり、pluginと外部contentを制限 | browserで表示、Docsifyのbuild不要、iOS限定viewer評価 | slide第一候補 |
| Slidev | MIT [公式](https://github.com/slidevjs/slidev) | Vue/Viteとbuild工程が増える、任意componentは信頼境界追加 | mobile表示の実機評価必要、制作環境の導入負荷大 | 比較候補、初期は見送り案 |
| PDF.js | Apache-2.0 [公式](https://mozilla.github.io/pdf.js/) | release継続を確認、scriptに関する[advisory](https://github.com/mozilla/pdf.js/security/advisories/GHSA-hq66-cqwq-w95j)も確認。修正版選定必須 | worker/ページvirtualization、最新版のSafari対応検証 | Web第一候補 |
| PDFKit | Apple SDK [公式](https://developer.apple.com/documentation/pdfkit) | OS更新を追随、暗号化/注釈等の受入試験必要 | iOS native、追加JSなし | iOS第一候補 |
| Mammoth.js | BSD-2-Clause [公式](https://github.com/mwilliamson/mammoth.js) | 構造抽出、sanitizeなしと公式に明記 | 小型DOCXをbrowser/PCで処理、iOSは派生再利用 | Word学習変換候補 |
| docx-preview | Apache-2.0 [公式](https://github.com/VolodymyrBaydalka/docxjs) | HTML制約下の描画、差分/脆弱性対応速度は採用前確認 | DOMが大きくなりやすい、長文は実機試験 | 追加比較候補 |
| LibreOffice | MPL-2.0を中心に複数OSSライセンス、[公式licenses](https://www.libreoffice.org/licenses/) | [公式filter/CLI案内](https://help.libreoffice.org/latest/en-US/text/shared/guide/convertfilters.html)、実行環境隔離と更新必要。正確な導入packageのLICENSE/NOTICEも確認 | PCのみ、font/CPU/起動負荷、iOSへ同梱しない | Office→PDF第一候補 |
| PptxGenJS | MIT [公式](https://github.com/gitbrent/PptxGenJS) | 生成用途、importには使わない | PC/browserのexport、mobile大容量は後続 | PPTX出力候補 |
| SheetJS CE | Apache-2.0、[公式license](https://docs.sheetjs.com/docs/miscellany/license/)。Proは別条件 | [公式配布案内](https://docs.sheetjs.com/docs/getting-started/installation/)に従いnpm名だけで最新と判断しない | 大型sheetはmemory制約、式再計算は別 | 低優先候補 |

maintenance評価は存在する公式repository/docs/releaseを確認した段階。各候補の未対応issue、更新頻度の期間集計、依存CVEの全件調査、実端末性能を実施済みとはしない。採用前に同じサンプル集合で比較する。

## PPTX読み込みの選定

browserだけで高忠実度を保証できるOSSは今回選定していない。専用OSS renderer候補はOOXML対応範囲・license・更新・mobile実績が確認できたものだけPoCへ進める。独自OOXML描画エンジンを作らず、まずLibreOfficeのPDF派生を採用候補とする。notes/text抽出は既存converter APIまたは小さな解析層を比較し、完全独自rendererと区別する。

## 導入ゲートと更新運用

固定版、公式release、SBOM/lockfile、license全文/NOTICE、transitive依存、security advisory、iOS Safari最低版とPC現行browserで確認。第三者コードは自己配信し、読み込みを必要なviewerだけへ限定する。download size/初期描画/memoryを測定し、ネット遮断状態でも使えるか確認する。結果は実装時のADRへ記録。

不採用候補の大きな依存を先に追加しない。PDF.jsの修正版利用に加えenableScripting=falseなどの設定を[セキュリティ設計](09-security.md)で必須化する。最新なら安全という判断はしない。
