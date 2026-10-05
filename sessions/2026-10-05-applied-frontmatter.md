# Applied記事のFrontmatter整備

- Vaultのwiki/study/フォーマット未解決にあった39件を確認。
- 本文一致の2件（アローダイアグラム、試験制度まとめ）はユーザー指示で除外し既存記事を維持。
- 残り37件にid・title・type: Applied・tags・created・updated・aliasesを追加し、ID名でAppliedへ移動。本文はbyte単位で保持。createdは整備日時。
- 同期前からあったEVMとofficial記事のID衝突を発見。未同期のEVMを20261005-170039へ変更。公開済みIDは維持。
- vault:prepareで148記事を同期。Vaultに先行して存在した他記事とCOALESCEの編集も標準同期で反映された。原本の記事本文は改稿していない。
- 索引生成・テスト成功、既存71記事のID/path維持を確認。git diff --check成功。
- コード・保守資料の既存未コミット変更を保持。commit/pushは未実施。
