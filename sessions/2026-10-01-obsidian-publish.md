# Obsidian同期から公開まで

- Vault 8件とcontent/notesの差分0を確認。study記事3件の削除、空titleのwiki記事1件追加を反映済み。
- vault:prepareのbuildは成功したが、削除された公開記事を固定IDで参照するoutput testが6件失敗した。
- output testを現行masterのroute・UI確認と独立Markdown fixtureの変換検証へ変更した。公開記事を復元してテストを通す対応は行わない。
- Sites sourceとローカルの履歴分岐は、HEAD間の差分が補助checkout参照のみであることを確認し通常mergeした。force pushは行わない。
- CONTENT_AUTHORINGにローカル準備とSites公開の境界、Codexへの一括依頼、成功判定を記録した。
- Vaultの空title/本文記事、標準Markdown linkから削除済み記事への参照は著者側の残課題。自動改稿しない。
- 旧docs記事は変更しないため旧索引は再生成しない。
- npm run checkはdomain 22件、output 4件とbuildが成功。git diff --checkも成功。
- Sites source push後、packageが未設定WSLのbashを呼んで失敗。既存Git BashをプロセスPATHの先頭へ指定して再実行する。
