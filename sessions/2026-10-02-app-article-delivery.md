# Windowsでアプリ向け記事配信を準備

- Mac未準備のため、記事配信仕様と生成処理を先に整えるユーザー方針に沿って実装した。
- 通常の同期へapp-articles.v1.json生成を追加。Schema版、一覧revision、記事metadata、LF正規化後のSHA-256を提供し、再生成の不要差分を避ける。
- app:verifyを追加し、HTTPS（ローカルのみHTTP）の一覧・本文を取得して照合できるようにした。
- 配信契約、構想、現行文書を更新し、ADR-009に判断を記録。
- 20テスト成功。正常取得とhash不一致・404・不正Schema・重複ID・不正path・改行差・移動・更新・削除を確認。
- vault:prepare成功。ローカルHTTPサーバーから55記事全件を取得し、hash一致を確認。既存Web metadata、README、sidebar、研修一覧、記事索引には差分なし。
- Vault原本は変更しない。同期中に見つかった利用者の記事編集は通常の生成ミラーへ反映した。以前の公開ログ調整の未commit変更も維持した。
- 未完了: 新配信ファイルのcommit/pushと公開先検証、MacでのiOS実装・ビルド。今回はWindows側の準備までとし、公開は実行していない。
