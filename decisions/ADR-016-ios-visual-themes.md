# ADR-016: iOSのLiving Auroraテーマ選択

status: accepted
updated: 2026-10-06

ユーザーがLiving Auroraの全テーマをLearnleafで選べるようにすることを依頼。元Web側の正式な選択肢を確認し、Living Aurora/Pulse Neon/Blue Cosmos/Windows 98の4種を採用する。

配色と形状、Markdown描画設定は`StudyTheme`に集約し、保存したテーマをSwiftUI Environmentで渡す。切替でNavigationStackや再生モデルを再生成せず、記事閲覧・音声再生中の状態を保持する。テーマと表示モードは端末内のUserDefaultsに保存し、学習記録backupへ混ぜない。

明暗は独立した表示設定とする。Windows 98は元の灰色面と黒文字の整合性を保つため明るい固定表示を使う。iOS標準の入力、タブ、メニューは操作とアクセシビリティを保ち、Windowsの操作体系そのものへ置換しない。

星空と回路模様は静的に描画し、星のseedを固定する。常時アニメーションは前回のUI合意に従い導入しない。記事本文はテーマの単色面として読みやすさを優先し、リンク・見出し・引用・表・コードの色へテーマを反映する。
