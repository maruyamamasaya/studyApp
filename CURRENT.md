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


iOS名称（2026-10-03）: ユーザー選択でLearnleafへ変更。ホーム画面のアプリ名と記事ホームの見出しを更新。実機ビルド成功、Vesperaへ上書き導入。bundle ID/記録保存形式は維持。ラジオの編集は台本修正→音声再生成→同期、番組の初期取り込みは制作側playlist JSON、個人編集はアプリの番組タブ、曲間は番組詳細で行う。


iOS聴取状態（2026-10-03）: 音声の正常再生終了時にtrackIDごとに聴取済みを保存。音声一覧・番組再生順にラベル、番組一覧/詳細に聴取済み本数を表示。再生画面と一覧の長押しで手動切替。スキップは完了にしない。同一音声の再同期/台本変更は状態維持、音声差し替えは未聴取へ。旧保存データは未聴取として互換読込。35件のSimulatorテスト成功。Vesperaへ署名ビルド・導入・起動成功。

2026-10-05: wikiへの集約に対応。studyフォルダ不要、development-logを追加。旧ミラーの削除保護は維持。

2026-10-05: 公開一覧55記事にdevelopment-logの記事を確認。旧iOS版はこの種別を拒否して一覧全体が形式エラーになる。手元の受け入れ修正にNode/Swiftの回帰テストを追加。Node 22件成功。対応版のMacビルド・XCTest・実機導入は未実施で、端末側のアプリ更新が必要。

2026-10-05: 任意のtypeと未指定（空欄・null・省略）を同期で受け入れる。未指定は配信一覧で空文字列。71記事の同期・Nodeテスト成功。iOS側も許可リストを廃止したが、Mac検証と端末更新は未実施。

## 未完了タスク

- [x] 自由なtype・未指定に対応したiOSアプリをMacでビルドし、XCTestを実行する（2026-10-05、統合版36件成功）。
- [ ] 対応版を端末へ導入し、Applied・development-log・type未指定の記事が一覧に表示され、本文を開けることを確認する。

2026-10-05: フォーマット未解決240件から単独で読める233記事を整備し、分野別階層へ移行。旧内部リンクは表示名へ戻した。リンク集5件はVaultのsettings/content-migration/2026-10-05-standaloneで保留、本文一致の重複2件は追加しない。原本バックアップあり。ローカル同期381記事・索引生成・テスト成功。公開pushと内容の事実確認は未実施。詳細はsessions/2026-10-05-standalone-import.md。

2026-10-05: Mac保存済みのLearnleaf機能を最新mainへ統合。公開取込記録のsource欄も既存記事と同じF社表記に匿名化し、記事ID・移行先・原本hashを保持。Web23テスト、既存SimulatorでのiOS36テスト（記事type・履歴・音声保存/差し替え/再開を含む）が成功し、索引再生成の差分なし。実機更新・ロック中再生・iCloud実ファイルの操作確認は別途必要。


iOS再生バーの配置（2026-10-05）: 各タブのNavigationStackと再生バーに独立した表示領域を確保。記事末尾の読了ボタンがバーに隠れる問題への対応。文字サイズに応じた再生バーの高さに追従する。


iOS番組編集（2026-10-05）: 番組の作成・名前変更・削除、取り込み済み音声の複数追加・解除、再生順と一覧順のドラッグ編集を追加。編集済み番組は端末側優先、削除IDも保存し再同期で復活しない。空番組を保持できる。現在の再生と途中再開のスナップショットは編集・削除で変更しない。

番組編集版の実機反映（2026-10-05）: Vesperaへ署名ビルド・上書きインストール・起動成功。ドラッグ編集や再生中編集の実機手動確認は残る。

記事配信互換（2026-10-05）: 公開catalogは381記事へ増加し、development-log/activity-log/Appliedと未分類の空typeが含まれる。iOSとHTTP検証器のstudy/wiki限定が一覧全体を拒否していたため、typeを分類用文字列として受け入れるよう修正。本文hash/取得先等の検証は維持。Vault同期のtypeは最新側の任意・未指定対応へ統合済み。

記事一覧互換修正版はVesperaへ上書き導入・起動成功。公開381記事のHTTP/hash検証、Node21件、Simulator38件成功。

案件001音声: 未制作39学習記事の掛け合い音声をVOICEVOXずんだもん/四国めたんで制作し、iCloud Drive/StudyAudioへM4A・台本・track JSONを追加。既存10本と合わせ49学習記事を5番組（10/11/8/9/11本）へ整理。既存音声・番組は保持。合計約148MB。OpenID Connectは本文未執筆のため関連する認証・認可記事を補足元とし台本と音声で明示。実機同期・聴感確認は残る。既存WAVの一括変換スクリプトはユーザー指定で後日対応。


iOS UI刷新（2026-10-06）: 実装プロンプトは[design/learnleaf-ui-prompt.md](design/learnleaf-ui-prompt.md)。下部タブを記事・聴く・検索・フォルダ・設定に整理。聴くで番組タイルと音声をまとめ、番組編集は管理から開く。記事ホームはピックアップ・お気に入り・検索・コレクションを中心に整理。Living Auroraの静かなViolet/Cyanの光と共通タイルを明暗対応で反映。共通検索は記事・音声・番組と詳細条件に対応し、記事本文は明示開始・取消・進捗/失敗件数付きで取得検索する。本文hash照合と既存保存形式は維持。

UI刷新の残課題と検証記録は[sessions/2026-10-06-aurora-ui.md](sessions/2026-10-06-aurora-ui.md)。UI刷新版はVesperaへ既存署名・同bundle IDで上書き導入し起動成功（2026-10-06）。実機でのデザイン評価と操作確認は残る。全文検索は端末メモリ内で、永続索引・オフライン検索は未実装。

性能調査（2026-10-06）: ホームのピックアップで比較ごとのhash再計算を確認。381記事のMac計算測定は約462ms/回、hash事前計算の比較案は約17msで同じ結果。音声同期の全検証/hashがMainActorで走り、変更なしでも約80msの参考値。検索も結果の複数回計算・ID全走査・再生進捗による再評価の候補がある。優先改善はピックアップの計算/保持、音声同期の処理分離、検索の計算/購読整理。実機Instrumentsは接続待ちtimeoutで未測定。詳細と測定条件は[sessions/2026-10-06-performance-audit.md](sessions/2026-10-06-performance-audit.md)。アプリコードは未変更。


記事一覧の軽量化（2026-10-06）: ユーザーの「記事のタイトルだけでよい」に合わせ、ホーム/お気に入り/検索/フォルダ/コレクションのカードから本文抜粋と自動本文取得を除去。正方形タイルはタイトルを最大4行にし、小さなmetadata/状態を維持。本文は記事を開く時と明示的な全文検索時のみ取得。ピックアップは記事ごとのhash事前計算と結果保持で改善し、UIスレッド外で選出する。音声同期と検索計算の残課題は継続。

タイトル表示・ピックアップ改善版はSimulator39テストと実機ビルド成功、Vesperaへ上書き導入成功（2026-10-06）。端末ロックにより起動確認は未完了。381記事の選出計算はMac中央値約16ms。詳細は[sessions/2026-10-06-title-only-cards.md](sessions/2026-10-06-title-only-cards.md)。音声同期と検索の性能課題は未対応。


iOSテーマ選択（2026-10-06）: Living Aurora / Pulse Neon / Blue Cosmos / Windows 98の4種を設定→テーマで選択・保存。Blue Cosmosに星空、Pulse Neonに回路模様、Windows 98に青緑背景と灰色の立体枠。カード・一覧・本文の色・再生バーへEnvironmentで反映。明暗は端末/ライト/ダークを別選択（Windows 98は明るい固定表示）。Simulatorビルドと41件XCTest成功。実機反映と全画面の実機評価は未実施。詳細は[sessions/2026-10-06-living-aurora-themes.md](sessions/2026-10-06-living-aurora-themes.md)。


Learnleafロードマップ段階1〜5（2026-10-06）: ユーザー指示で段階ごとに実装/テストし、最後にまとめて確認する。プロンプトはdesign/learnleaf-roadmap-prompts.md。検索の重複計算を除き、音声同期の検証を別タスクへ分離。検索条件保存/履歴/並び順/個別解除、関連記事と記事・音声・番組の相互導線、コレクションの関連記事音声、タグ指定ピックアップ、hash検証済みcatalog/本文の端末保存・容量/削除・全記事取得、v1 JSONの安全な記録統合を追加。端末間転送はファイル経由で、自動iCloud同期は未対応。最新の検証と制限はsessions/2026-10-06-roadmap.md。過去の「永続保存未実装」は今回更新済み。音声同期の確定I/Oと一括Data読取は残る。

ロードマップ版の検証: 最終50件XCTest、Node21件成功。索引再生成差分0・diff check成功。iPhone/iPad Simulatorへ最終版導入、iPad縦/横表示、381記事の端末保存（失敗0・3.4 MB）、検索条件保存とコレクション作成保存を確認。実機反映は未実施。

ロードマップ版の実機反映（2026-10-06 22:29 JST）: 既存Team・同bundle IDで署名ビルド成功、Vesperaへ上書きインストール・起動成功。デザインと実音声操作の評価はユーザー確認待ち。

最新main取込（2026-10-06）: 取得済みorigin/main（a8d523a）へ更新し、公開記事・取込記録の匿名化と自由なtype対応をローカルのLearnleafロードマップ版へ統合。実機導入は上記22:29の記録を参照。自由なtypeの記事表示・本文の実機手動確認は引き続き残る。

リモート反映（2026-10-07）: ユーザー承認で統合済みLearnleaf変更をmainへcommit/pushする。前回のWeb24件・iOS51件成功を確認。公開記事の差分はなく、Pagesの自動deploy対象外。実機手動確認の残課題は継続。

未解決（2026-10-08）: Vault同期チェックが `docs/wiki/anken/anken001/20261001-145031.md` の「同期先を直接変更しているため上書きしません」で停止。原因は未特定。10/6〜10/8の個人開発メモはVault保存済みだがStudy Appへ未同期。ユーザー指示で課題として記録し、修正・同期・公開は保留。詳細は[sessions/2026-10-08-vault-sync-issue.md](sessions/2026-10-08-vault-sync-issue.md)。

統合学習機能の設計（2026-10-08）: SVG図解・プレゼンテーション・Office/PDF資料を既存Study Appへ統合する調査と10本の設計書を[design/integrated-learning](design/integrated-learning/README.md)へ追加。状態は提案、実装未着手。添付配信基盤と安定リソースID、ローカルOffice変換、Web/iOSの共通配信を推奨。公開/private境界、iOS viewer、変換環境と実機上限は実装前の判断事項。現行アーキテクチャ・依存・公開記事は変更しない。
