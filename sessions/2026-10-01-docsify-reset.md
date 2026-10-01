# Docsifyへの整理

- ユーザー承認によりDocsifyへ戻し、AIなしのVault同期・索引更新・Git pushへ書き直した。
- 記事原本をVaultで維持し、5記事をdocsへ同期。Frontmatter ID、title、aliasを索引へ反映する。
- Astro/app/dist/content/generated/migration/.openai/.sites-checkoutを削除し、依存307個をprune。過去ADRとsessionsは保持した。
- クライアントpassword gateを廃止し、記事HTMLはDOMPurifyでsanitizeする。
- npm tests、Python索引生成とdiff checkが成功。
- 個人所有の非公開repositoryへのPages作成はGitHubプラン制約で422。サイト一般公開は承認済みだがrepository公開可否は確認中。
- 14テスト成功。同期checkは5記事・差分0。索引の再生成でも記事IDを含むmasterは変化しなかった。diff checkは改行警告のみで成功。
- ローカルブラウザーでホーム、同期記事（title表示・Frontmatter非表示）、研修ホームの表示を確認した。
- repositoryとGit履歴の公開承認を得てpublicへ変更。Pagesをworkflow方式で設定。origin/mainはローカルHEADの祖先で分岐なし（0/7）。初回deployを実行する。
- 旧Sitesのリモートサイトは削除していない。添付ファイル同期は未対応。
- 初回公開: commit fad01db、Actions run 36826656659がcompleted/success。https://maruyamamasaya.github.io/studyApp/ で一覧と記事本文を実ブラウザー確認済み。
