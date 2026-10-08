# 9. セキュリティ設計書
状態: 設計案。現行の公開構成と上書き保護を弱めない。

## 信頼境界

Vaultのファイル、端末import、Office内部XML、SVG、PDF、AI生成物はすべて未検証入力。安全化派生と署名なしのhashは内容の安全保証ではなく、別々の検証が必要。一般公開Git/Pagesは秘密資料を保持できない。private原本/notesをrepositoryやdocsへ入れない。

public許可はmetadataの既定falseと操作時の明示確認、公開対象一覧のレビューで決定。派生PDF/text/thumbにも機密が残る。匿名化/公開可否は自動sanitizeとは別。公開後のGit履歴/第三者cacheは単純削除で回収できない。

## SVG policy案

XMLをDTD/外部entity無効でparseし、script、on*イベント、foreignObject、iframe/object/embed、外部href/xlink:href、javascript/file/data URL（一般値）、外部use/image/font、CSS @import/urlを既定拒否する。内部#参照は検証済みelementに限定し、許可するraster埋込画像は実体判定・容量制限・再encodeしたものだけ派生に再挿入する。

DOMPurifyを最終HTML/SVG sanitizeに使っても、外部fetch・filter計算量・原本配信をそれだけで防げない。幅/高さ/viewBox、path長、node数、filter、animationにも上限を設ける。初期profileは静止SVGとし、animate/set/CSS animationを削除または拒否、将来の制限付きanimationは別profile+Reduce Motion停止を必須にする。

記事内はimg/PNG派生優先。要素リンクが必要な場合のみ安全化inline SVGを隔離viewerへ載せ、elementIDはmetadataからviewerが処理する。危険原本を同一originの直接URLで配信しない。IDをprefixしてDOM衝突を防ぎ、関連リンクはarticle/resource allowlistで解決する。

## HTML・PDF・Office

DOCX変換HTMLはsanitize後に挿入し、その後のDOM加工で危険属性を復活させない。[Mammoth公式security](https://github.com/mwilliamson/mammoth.js#security)。
OOXMLはZIP entry名/件数/展開size/ratioを解凍中も制限、外部relationships/DTDを無効化。macro付き形式、埋込OLE、active contentは拒否または隔離、実行しない。Office converterはネット遮断、専用user/profile/temp、macro/外部リンク更新禁止、timeout/CPU/memory制限付きprocessで動かす。

PDF viewerはscript/actions/自動添付実行/外部リンク自動遷移を禁止、PDF.js enableScripting=false、必要ならisEvalSupported=false、修正版と厳格CSPを使用。公式に[script関連のadvisory](https://github.com/mozilla/pdf.js/security/advisories/GHSA-hq66-cqwq-w95j)がある。PDFKitについても機能を同等に止められるかPoC検証し、未達なら静止派生へ限定する。リンクを開くのは本人操作時、http(s)許可と表示確認を行う。

## viewerとファイル境界

専用viewer文書にCSP metaを設定する案。scriptは固定viewer bundleのみ、connect/img/fontは必要な自己配信/検証済みblobに限定。CSPでPDF/SVG内の任意scriptを許さない。Web iframeは必要な権限だけsandbox、allow-scriptsとallow-same-originの同時使用で同origin隔離が崩れないか検証する。postMessageはorigin/source/schemaを検証。iOS WKWebViewは任意navigation/通信/ファイルアクセス拒否、bridgeへidだけ渡し任意command/HTML/URLを渡さない。

ブラウザーやiOSから選ばれたファイルは許可されたscopeだけ読み取り、保存先は固定root配下。canonical path検証、..・絶対path・symlink・二重encode traversalを拒否。拡張子/MIMEだけで信頼せずsignatureと内部構造を確認。原本の公開downloadが必要なら安全な形式の許可と公開設定を別に判定する。

## 検証マトリクス

| 入力/状況 | 期待結果 |
| --- | --- |
| SVG script/event/foreignObject/外部font/use/CSS URL | 除去または拒否、外部通信0、説明警告 |
| SVG巨大filter/path、ZIP bomb | 制限内で停止、UI応答維持 |
| DOCX javascriptリンク/外部画像/埋込OLE | 実行/通信0、原本と派生を隔離 |
| PDF script/action/添付、悪性font | script実行0、parser失敗は安全に終了 |
| path traversal/symlink/異なるhash | 確定保存/公開を拒否 |
| private notes/コメント/author | 公開previewから除外、公開対象を再確認 |
| 更新中/取消/容量不足 | 既存原本・公開版・学習記録を保持 |

AI/RAG入力内の指示は資料の内容として扱い、権限/公開policyを変更させない。外部AI送信は資料単位の許可と送信範囲確認を追加する。これらのテストは実装時に必要で、今回対策コードを追加したとは扱わない。
