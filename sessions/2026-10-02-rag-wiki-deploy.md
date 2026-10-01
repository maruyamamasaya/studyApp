# RAG学習Wikiの同期と公開

## 調査・変更

- ユーザーが学習資料50件のデプロイを依頼した。
- wiki内のtype: studyを拒否する同期制約を確認し、配置フォルダと記事種別を分離。未対応typeの拒否と上書き保護を維持した。
- Vault原本を変更せず55記事を同期し、一覧・研修一覧・検索索引を生成した。
- CURRENT、ARCHITECTURE、CONTENT_AUTHORINGを更新し、判断をADR-007へ記録した。

## 検証

- vault:prepare成功、15テスト成功、git diff --check成功。
- 既存記事マスター7件のID維持、新規50件の同期本文とVault原本の完全一致を確認。

## 残課題

push後にGitHub Actionsの完了と公開先の記事を確認する。
