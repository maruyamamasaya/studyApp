# 現在の状態

更新: 2026-10-02

- 現行方式はDocsify。Obsidian Vault `Document organization`の`wiki/`が記事の唯一の正本。
- UIはスマホ中心の新しいreaderへ刷新。旧DocsifyテーマCSSを廃止し、900px以下ではフォルダパネル・検索/目次操作、PCでは左sidebarと中央本文を表示する。
- `docs/`に55記事と一覧・索引を同期する。案件WikiのRAG学習記事50件を追加。FrontmatterのIDを維持し、title・aliasでWiki Linkを解決する。
- 保存フォルダと記事種別は独立。`wiki/anken001/`内の`type: study`も原本どおり同期し、研修一覧に掲載する。
- `npm run vault:prepare`で同期・索引生成・テスト。`sync-and-publish.cmd`または`npm run vault:publish`でその後GitHubへのcommit/pushを行う。Codex・AIは使用しない。
- 日常の同期・公開は成功時の要約のみ表示し、記事の末尾空白では停止しない。Frontmatter/ID/上書き保護とテストは維持。詳細ログは`--verbose`。
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

iOS版はWindowsで初期コードを実装済み。[IOS_APP_CONCEPT.md](IOS_APP_CONCEPT.md)に記事共通・機能と記録独立・PagesからHTTPS取得の方針を整理した。通常同期でapp-articles.v1.jsonを生成し、app:verifyでHTTP取得と本文hashを確認できる。[APP_ARTICLE_DELIVERY.md](APP_ARTICLE_DELIVERY.md)にv1契約を記載。初期実装はcfedff4でmainへpush済み、Pages deployと55記事の公開HTTP検証に成功。ios/にSwiftUIの一覧・本文・内部リンク・読了・学習時間・履歴・JSONバックアップを追加。[ios/README.md](ios/README.md)にMacでの手順と未対応事項を記載。

事前生成音声の受け入れを追加: 「聴く」タブ、iCloud Drive等の制作物フォルダ同期、管理JSONのarticleIDとUUIDのtrackIDによる自動紐付けと音声差し替え、台本の表示、端末内コピー、再生位置・倍速・BGM・バックグラウンド/ロック画面操作。制作ツールはこれからVOICEVOX等を使って用意する方針。受け入れ形式は[ios/AUDIO_IMPORT.md](ios/AUDIO_IMPORT.md)。MacのXcodeビルド・型検査・23件のXCTest・実機確認は未実行。

ラジオ構成: *.playlist.jsonの配列順で連続再生、標準3秒/0〜10秒のインターバル、BGM、前/次、最後の番組の途中再開を実装。仕様とMacでの確認は[ios/RADIO_PLAYBACK.md](ios/RADIO_PLAYBACK.md)。ユーザー依頼で音声機能一式をリモートへ反映する。

2026-10-05: wikiへの集約に対応。studyフォルダ不要、development-logを追加。旧ミラーの削除保護は維持。

2026-10-05: 公開一覧55記事にdevelopment-logの記事を確認。旧iOS版はこの種別を拒否して一覧全体が形式エラーになる。手元の受け入れ修正にNode/Swiftの回帰テストを追加。Node 22件成功。対応版のMacビルド・XCTest・実機導入は未実施で、端末側のアプリ更新が必要。

2026-10-05: 任意のtypeと未指定（空欄・null・省略）を同期で受け入れる。未指定は配信一覧で空文字列。71記事の同期・Nodeテスト成功。iOS側も許可リストを廃止したが、Mac検証と端末更新は未実施。

## 未完了タスク

- [ ] 自由なtype・未指定に対応したiOSアプリをMacでビルドし、XCTestを実行する。
- [ ] 対応版を端末へ導入し、Applied・development-log・type未指定の記事が一覧に表示され、本文を開けることを確認する。

2026-10-05: フォーマット未解決240件から単独で読める233記事を整備し、分野別階層へ移行。旧内部リンクは表示名へ戻した。リンク集5件はVaultのsettings/content-migration/2026-10-05-standaloneで保留、本文一致の重複2件は追加しない。原本バックアップあり。ローカル同期381記事・索引生成・テスト成功。公開pushと内容の事実確認は未実施。詳細はsessions/2026-10-05-standalone-import.md。
