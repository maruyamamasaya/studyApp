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

事前生成音声の受け入れを追加: 「聴く」タブ、iCloud Drive等の制作物フォルダ同期、管理JSONのarticleIDとUUIDのtrackIDによる自動紐付けと音声差し替え、台本の表示、端末内コピー、再生位置・倍速・BGM・バックグラウンド/ロック画面操作。制作ツールはこれからVOICEVOX等を使って用意する方針。受け入れ形式は[ios/AUDIO_IMPORT.md](ios/AUDIO_IMPORT.md)。MacのXcodeビルド・23件のXCTestは成功。Vesperaへの署名付きインストールと起動成功。音声のFile Provider・バックグラウンド操作等の実機確認は未実施。

ラジオ構成: *.playlist.jsonの配列順で連続再生、標準3秒/0〜10秒のインターバル、BGM、前/次、最後の番組の途中再開を実装。仕様とMacでの確認は[ios/RADIO_PLAYBACK.md](ios/RADIO_PLAYBACK.md)。ユーザー依頼で音声機能一式をリモートへ反映する。

Mac検証（2026-10-02）: Xcode 26.6でSimulatorの23件XCTest、Vesperaの実機ビルド・導入・起動が成功。記事取得エラー表示のSwiftコンパイルエラーを修正し、抽象的なアプリアイコンを追加。Node 24で既存20テスト成功、公開54記事のHTTP/hash検証成功、索引再生成の差分なし。音声・読書操作の実機手動確認は残る。

iOSデザイン刷新: 前回の記事、日替わりピックアップ3件（手動入れ替え）、タグ一覧と絞り込み、階層フォルダ・件数・開閉保存、お気に入りとコレクション作成/名前変更/削除/記事追加・解除を追加。本文の文字・余白・見出し・引用・表・コードを調整。保存情報は既存backup v1に後方互換のoptional fieldsで含める。前回の記事は記事単位の再開で、スクロール位置の保存は未実装。

iOS表示調整: フレイバーテキストを削除し、記事カードと前回の記事に本文冒頭の2行抜粋を追加。表示するカードで本文を取得しhash照合、ID+本文hash単位でメモリ再利用。抜粋は最大140文字、見出し/Frontmatter/コードを除く。

iOSホーム: MyMusicの同一commit（1cca1135）のHomeCarouselSection/HomeItemTileを参照し、ピックアップとお気に入りを正方形タイルの横カルーセルへ変更。カード単位でスナップし、タイトル・冒頭2行・タグ・状態を表示。検索/タグ/フォルダの結果は読みやすい縦一覧を維持。

iOSホームの表示順をタグ→前回の記事→ピックアップ→お気に入りに変更。前回の記事は文字と余白を抑えた小さなカードで表示する。

iOS文字サイズ: 標準文字をcallout、一覧タイトル/セクションをsubheadline、タイルタイトル/抜粋をfootnoteへ縮小。本文は17→16、記事タイトルはlargeTitle→title。小さなタグ/補足は維持し、Dynamic Typeを制限しない。

iOSカルーセル: 標準文字サイズで横に約2.5枚が見えるよう、画面の利用幅と10pt間隔から正方形の一辺を算出。カード余白10、タイトル2行、冒頭2行。文字拡大時は読みやすさを優先してカードも拡大する。

iOS学習履歴: 記事ID単位に集計し、最後の学習区間終了時刻の降順で表示。記事タイトルと合計時間だけを表示し、元のsession/backup形式は維持する。

iOSナビゲーション: 下部は記事・聴く・フォルダ・設定。学習履歴は設定の「学習記録」から開く。今回の変更はSimulatorで確認済み、ユーザー指示によりVesperaへのデプロイは保留。


iOS音声UI（2026-10-03）: 下部タブを記事・聴く・番組・フォルダ・設定に変更。聴くは音声一覧と再開、番組は独立した一覧・詳細で曲間と再生順を扱う。記事の「この記事を聴く」は専用再生ページへ直接遷移。聴く/番組の下部にミニプレイヤー、設定に音声・同期を配置。Simulatorビルド・既存XCTest・空状態の導線確認成功。Vesperaへの署名ビルド・上書きインストール・起動成功（2026-10-03）。実音声操作の手動確認は未実施。

iOS再生バー: 音声選択後は全タブの下部、タブバーのすぐ上にミニプレイヤーを表示。記事本文やフォルダから開いた記事を見ながら再生/一時停止でき、タップで詳細再生画面を開く。再生進捗も表示する。


iOS実機反映（2026-10-03）: 全タブの再生バーを含む最新版をVesperaへ署名ビルド・上書き導入・起動成功。RAG関連記事3本（Chunk/Embedding/Hybrid Search）の掛け合い音声と「RAGラジオ・仕組み編」はiCloud経由で実機に同期済み。実機一覧の音声hash・台本・番組再生順が制作物と一致。実再生の聴感確認は残る。


iOS名称（2026-10-03）: ユーザー選択でLearnleafへ変更。ホーム画面のアプリ名と記事ホームの見出しを更新。実機ビルド成功、Vesperaへ上書き導入。bundle ID/記録保存形式は維持。ラジオの編集は台本修正→音声再生成→同期、番組名/順番は制作側playlist JSON、曲間は番組詳細で行う。


iOS聴取状態（2026-10-03）: 音声の正常再生終了時にtrackIDごとに聴取済みを保存。音声一覧・番組再生順にラベル、番組一覧/詳細に聴取済み本数を表示。再生画面と一覧の長押しで手動切替。スキップは完了にしない。同一音声の再同期/台本変更は状態維持、音声差し替えは未聴取へ。旧保存データは未聴取として互換読込。35件のSimulatorテスト成功。Vesperaへ署名ビルド・導入・起動成功。

2026-10-05: wikiへの集約に対応。studyフォルダ不要、development-logを追加。旧ミラーの削除保護は維持。

2026-10-05: 公開一覧55記事にdevelopment-logの記事を確認。旧iOS版はこの種別を拒否して一覧全体が形式エラーになる。手元の受け入れ修正にNode/Swiftの回帰テストを追加。Node 22件成功。対応版のMacビルド・XCTest・実機導入は未実施で、端末側のアプリ更新が必要。

2026-10-05: 任意のtypeと未指定（空欄・null・省略）を同期で受け入れる。未指定は配信一覧で空文字列。71記事の同期・Nodeテスト成功。iOS側も許可リストを廃止したが、Mac検証と端末更新は未実施。

## 未完了タスク

- [x] 自由なtype・未指定に対応したiOSアプリをMacでビルドし、XCTestを実行する（2026-10-05、統合版36件成功）。
- [ ] 対応版を端末へ導入し、Applied・development-log・type未指定の記事が一覧に表示され、本文を開けることを確認する。

2026-10-05: フォーマット未解決240件から単独で読める233記事を整備し、分野別階層へ移行。旧内部リンクは表示名へ戻した。リンク集5件はVaultのsettings/content-migration/2026-10-05-standaloneで保留、本文一致の重複2件は追加しない。原本バックアップあり。ローカル同期381記事・索引生成・テスト成功。公開pushと内容の事実確認は未実施。詳細はsessions/2026-10-05-standalone-import.md。

2026-10-05: Mac保存済みのLearnleaf機能を最新mainへ統合。公開取込記録のsource欄も既存記事と同じF社表記に匿名化し、記事ID・移行先・原本hashを保持。Web23テスト、既存SimulatorでのiOS36テスト（記事type・履歴・音声保存/差し替え/再開を含む）が成功し、索引再生成の差分なし。実機更新・ロック中再生・iCloud実ファイルの操作確認は別途必要。
