# 記事一覧の拡張種別への互換対応

ユーザー報告: 番組編集版導入後に「記事一覧または取得先の形式が不正です」。公開catalogを一次情報として取得し、HTTP検証器でも再現。公開381件にdevelopment-log 23件、activity-log 34件、Applied 58件、空type 1件があり、study/wiki限定検証で一覧全体を拒否していた。番組編集は記事取得処理を変更していない。

ArticleClientとapp catalog検証器のtypeを分類用文字列として受け入れるよう修正。空文字は未分類として保持。typeはiOSの取得可否に使わず、分類metadataに留める。ID、重複、取得path、schemaVersion、本文hash、HTTPS/リダイレクト制限は維持。Vault Frontmatterの必須type検証は変更せず。APP_ARTICLE_DELIVERY/CURRENT/ARCHITECTUREを更新。

検証: Node全21件、Simulator全38件成功。拡張種別・空typeと不正path/非文字列拒否の回帰テストを追加。公開381記事のHTTP取得・形式・本文hash一致。既存Teamで実機署名ビルド成功、Vesperaへ同bundle IDで上書きインストール・起動成功。

Simulator: 既存F26F773A-A316-4610-9228-84217FEEB82A、並列無効、最大同時端末1、derivedData /tmp/learnleaf-program-build。実行コマンドはprogram-editing sessionのものと同一。ログと前後device set・日時・プロセス記録は /tmp/learnleaf-article-tests/。xcodebuild/xctest/runner終了確認済み、XCTestDevices前後18台、追加IDなし。今回の複製0、削除0、今回残存0、他の18台は保持。Node/公開検証ログは /tmp/learnleaf-program-tests/article-node.log とarticle-public.log。

残課題: 実機の記事画面はユーザー側の確認が残る。公開元の拡張種別/空typeの生成経路はこのMacのローカル同期構成と異なり、Windows側の生成規則は未調査。アプリ内の保存記録と音声は変更しない。
