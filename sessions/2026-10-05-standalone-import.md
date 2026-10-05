# 単独で読める記事の移行

- 対象: Vault wiki/フォーマット未解決以下240 Markdown。全件YAML未設定。
- 233件にYAMLを追加し、元の分野別階層をwiki直下に保持してID名へ移動。元のfilenameをtitleへ採用。作業ログはdevelopment-log、学習記事はstudy、tags/aliasesは空配列。createdは今回の整備日時。
- 旧内部Wiki Linkは表示名（aliasがなければ末尾のページ名）へ変換。コードブロック・inline code・外部Markdown URLを保持。本文内容の改稿とリンク復旧は行っていない。
- リンク集のみの5件をsettings/content-migration/2026-10-05-standalone/保留へ保管し、同期から除外。Reactの全体像・Webマーケティング全体ロードマップは説明本文があるため維持。
- 本文が一致するネットワーク基礎編とSEO第2章の重複2件は追加しない。
- 原本240件を同ディレクトリのoriginalsへ保存、SHA-256一致を確認。移行対応表: 2026-10-05-standalone-import.json。
- vault:prepare成功: 381記事、索引生成・テスト成功。追加233記事のmetadata掲載とVault/docs本文一致、既存公開記事ID/path維持、git diff --checkを確認。
- 公開push未実施。既存コード・文書の未コミット変更を保持。
- 残課題: 保留5件の必要性判断、記事内容の事実確認・古い説明の更新は未実施。今回の選別はリンク先に依存しない説明本文の有無を基準とした。
