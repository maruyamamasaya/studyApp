# iOS記事一覧の種別エラー調査

- 公開app-articles.v1.jsonはschemaVersion 1、55記事。20261005-093655（wiki/official/20261005-093655.md）がdevelopment-log。旧ArticleClientはstudy/wikiのみ許可しており、一覧全体をReaderError.invalidにする。
- 既存の未コミット変更にdevelopment-log対応があることを確認し、その変更を維持。配信側NodeとiOSの混在種別・未知種別拒否の回帰テストを追加。配信仕様と実機確認項目を更新。
- npm testは22件成功。SwiftテストはWindowsでは未実行。公開HTTP一覧/全本文の検証とdiff確認は下記に記録。
- 公開app:verify成功（55記事、一覧形式・HTTP取得・全本文hash一致）。git diffとstatusを確認し、git diff --check成功。既存の未コミット変更は維持した。
- 今夜は対応ソースをMacへ取得し、Xcodeでビルド・Product > Testを実行後、アプリを実機へ更新。一覧更新、追加記事の本文、既存記事と記録保持を確認。サイト再公開だけでは旧アプリの検証処理は変わらない。
- 同期、索引再生成、commit/push、実機導入はこの作業では実行しない。
