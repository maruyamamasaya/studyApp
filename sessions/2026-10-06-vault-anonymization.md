# Vault 5記事の匿名化

- 対象: ユーザー指定の5記事。原本は隣接する Document organization Vault。
- 修正版: GitHub commit `6bb61a880403c022cc3d9bcafe764d46613193c1` の対応する docs/wiki。修正前は親 `80016a5f3aad7b20bb833c9783ef35fb4777a518`。
- 先にVault・repository外のローカルへ5原本をバイト単位でバックアップ。保存先は `.codex/visualizations/2026/10/06/01a10e89-45a9-7a12-8bf1-3933359684c9/vault-anonymization/originals`（ユーザープロファイル下）。公開・Vault同期対象外。
- 改行コードだけLFへ正規化して全文を比較。5件すべて修正前に一致し、指定修正版へ置換。修正済み0件、競合0件。原本のCRLF/LF形式を維持。
- 置換後の5件が指定修正版と一致。YAMLが有効でid/created/typeを維持。2件のFrontmatter変更は指定修正版に含まれる匿名化として反映。
- 公開同期・索引生成・push・Git履歴書換えは実施していない。構成変更なし。原本本文・実名は記録しない。
- 残課題: 今回の範囲に未解決なし。公開反映は今回の対象外。
