# 現在の状態

更新: 2026-10-02

- 現行方式はDocsify。Obsidian Vault `Document organization`の`study/`・`wiki/`が記事の唯一の正本。
- UIはスマホ中心の新しいreaderへ刷新。旧DocsifyテーマCSSを廃止し、900px以下ではフォルダパネル・検索/目次操作、PCでは左sidebarと中央本文を表示する。
- `docs/`に55記事と一覧・索引を同期する。案件WikiのRAG学習記事50件を追加。FrontmatterのIDを維持し、title・aliasでWiki Linkを解決する。
- 保存フォルダと記事種別は独立。`wiki/anken001/`内の`type: study`も原本どおり同期し、研修一覧に掲載する。
- `npm run vault:prepare`で同期・索引生成・テスト。`sync-and-publish.cmd`または`npm run vault:publish`でその後GitHubへのcommit/pushを行う。Codex・AIは使用しない。
- 公開先はGitHub Pages。ユーザーはサイト・repository・Git履歴の公開を承認した。repositoryをpublicへ変更し、PagesをGitHub Actions方式で設定済み。URLは https://maruyamamasaya.github.io/studyApp/ 。
- Astro実装、dist、contentミラー、generated、Sites設定、Codex CLI公開処理と不要な依存を削除した。旧設計判断と作業履歴はdecisions/・sessions/に保存する。
- `.github/workflows/pages.yml`がmainへのpush後、docsを静的配信する。公開結果はActionsで確認し、push成功だけをdeploy成功と扱わない。
- 公開サイトにはログイン制限を設けない。旧クライアント側password gateは認証ではないため現行公開サイトから除去した。
- 旧Astroの学習状態version 2は自動移行しない。Docsify reader toolsのブラウザー保存状態は別扱い。
- PythonがPATHにない場合はSTUDY_APP_PYTHONで指定。このPCではインストール済みのbundled Pythonも検出する。AI呼び出しは不要。

検証済み: 15テスト、同期差分0、索引ID維持、diff check。RAG学習記事50件を公開metadataとブラウザー本文・内部リンクで確認。

RAG学習記事のPages deploy成功（Actions run 36943720864、commit a72287f）。

初回Pages deployは成功（Actions run 36826656659、commit fad01db）。公開URLで記事一覧・本文表示を確認済み。

残課題: 旧Sitesのリモートサイトは残っている。画像・添付ファイル同期は未対応。Vaultバックアップ方針は未決定。
