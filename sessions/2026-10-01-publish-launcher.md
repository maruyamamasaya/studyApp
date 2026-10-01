# 同期・公開の一括入口

- cmdのダブルクリックまたはnpm run vault:publishから同期・検証・Sites公開を順に実行する入口を追加した。
- 独立バッチにはSitesの永続credentialを与えず、既存ログイン済みCodex CLIのApps経由で短期credentialとnative deploymentを取得させる。
- Codex CLIはapprove-for-meで起動し、承認reviewを無効化しない。
- 同期／diff check失敗時の公開停止、deployment結果のfailed／ID欠落／別domain拒否をテストする。
- Sites CLI接続とdeployのend-to-end確認は未完了。check-onlyはCLIログインとローカル前提のみを確認する。
- 新しいMarkdownは保守資料のみで旧docsを変更しないため旧索引は再生成しない。
- npm run check（domain／sync／launcher 25件、output 4件、8記事build）成功。cmd --check-onlyで既存ログインと起動条件を実環境確認した。git diff --check成功。
- ユーザーの実行でCLIがgpt-6.1-solをChatGPT accountで未対応として拒否した。ローカルmodels_cacheの可視モデルにgpt-6-solがあることを確認し、公開CLI専用に--model gpt-6-solを明示指定するよう修正した。STUDY_APP_PUBLISH_MODELで上書き可能。モデル引数・overrideを含むlauncher test 4件成功。修正後の実deployは未確認。
