# アーキテクチャ

更新: 2026-10-08

## iOSの図解・資料・スライド

Files → VisualResourceStore(actor) → Application Support/StudyApp/visual-resources（索引JSON、UUID/hash原本、派生PDF・サムネイル）。VisualResourceModelがUIに供給する。記事IDで既存一覧と関連付け、資料UUIDとスライドIDは独立する。公開記事・音声・StudyBackupと保存形式を共有しない。

- VisualResources / OfficeValidation / SafeSVG: metadata・容量・ZIP/XML・静的SVG検証。
- SVGViewer / DocumentViewer: JSを無効化したWKWebView、PDFKit、Quick Look。PPTXは利用者が別途作成したPDFを登録する。
- VisualSlides / VisualExports: Markdown構造分割、草稿編集・更新比較、ネイティブプレゼン、SVG/PNG/PDF/ZIPのローカル出力。
- VisualLibraryView / SearchView / StudyApp: 資料一覧・分類・記事/要素関連、既存検索と記事末尾・設定からの導線。

記事内SVGの遠隔取得は既存Pages配信元に限定し、リダイレクトを拒否して受信量を制限する。個人資料のクラウド同期や公開manifestは追加しない。方式の判断は[ADR-018](decisions/ADR-018-ios-local-visual-resources.md)、操作・制限・未検証事項は[iOS手順書](ios/VISUAL_RESOURCES.md)。

```text
Obsidian Vault / wiki
  ↓ 検証と一方向同期（Node.js）
docs/study・docs/wiki のMarkdown
  ├─ _article-metadata.json（title・alias・ID）
  ├─ app-articles.v1.json（アプリ用の版付き一覧・本文hash）
  ├─ README.md・_sidebar.md・training/README.md
  └─ build_note_index.py → _note-index.json・_article-master.json
  ↓ commit / push
GitHub repository
  ↓ GitHub Actions（HTML buildなし）
GitHub Pages → DocsifyがブラウザーでMarkdownを描画
             → iOSアプリ（Macビルド・テスト検証済み）がJSONとMarkdownをHTTPS取得
```

- `scripts/lib/article.mjs`: YAML、Frontmatter、ID、created、重複の検証。依存はyamlのみ。
- `scripts/lib/app-articles.mjs`: 検証済み記事からアプリ向け一覧を生成。schemaVersion、revision、ID、相対path、表示metadata、LF正規化後の本文hashを持ち、変更なしの生成で差分を出さない。Web用metadataとは独立する。
- `scripts/verify-app-catalog.mjs`: 指定配信元から一覧と全記事をHTTP取得し、形式・取得成功・本文hashを確認する読取専用CLI。契約はAPP_ARTICLE_DELIVERY.md。
- `scripts/sync-obsidian-content.mjs`: Vaultからdocsへの同期。`obsidian-sync-manifest.json`のhashで管理し、直接変更・管理外上書き・不正な削除pathを拒否する。空ファイルは下書きとして除外する。
  保存フォルダと記事種別は独立し、相対パスとFrontmatterを維持する。typeは任意の文字列・空欄・省略を許可し、未指定はmetadataとアプリ一覧で空文字列に正規化する。研修一覧はtypeがstudyの記事を配置場所によらず掲載する。
- `scripts/prepare-obsidian-content.mjs`: 同期、Python索引生成、テスト。成功時は要約、失敗時は詳細を表示する。`--verbose`で詳細ログを表示する。日常の公開では記事の末尾空白を停止条件にしない（diff checkは開発時に別途実行）。
- `scripts/publish-obsidian.mjs`: mainとoriginを確認し、prepare成功後docsとmanifestだけをcommit/pushする。ステージ済みの無関係な変更があると停止する。force pushや自動mergeは行わない。
- `docs/index.html`と`docs/training/index.html`: Docsifyの入口。記事URLはhash route。HTTP serverで動作する。
- `docs/content-tools.js`: 表示時にFrontmatterを隠してtitleを付け、DOMPurifyで描画HTMLをsanitizeする。
- `docs/obsidian-wikilinks.js`: Wiki Linkのtitle・alias・filename索引からリンクを生成する。
- `docs/folder-navigation.js`: 記事metadataのpathからVaultのフォルダ階層を組み立て、開閉状態をブラウザーに保存する。現在の記事の祖先を開き、記事を強調する。研修サイトは独立した従来navigationを維持する。
- `docs/reader-tools.js`・`styles.css`・`unique-heading-ids.js`: 従来のテーマ、検索、学習状態、目次等の閲覧支援。
  学習状態・時間・チェックリスト等の保存処理を維持する。旧テーマCSSは使用しない。
- `docs/reader-shell.js`・`styles.css`: スマホ中心の新UI。900px以下はフォルダdrawer・下部検索/目次、901px以上は左sidebar・中央本文。記事名、tags、学習時間を本文先頭にまとめ、入口はmetadataから記事カードを構築する。overlay閉鎖とinertも管理する。
- `.github/workflows/pages.yml`: docsだけをPages artifactとして配信。秘密情報・Vault全体・保守資料をartifactへ含めない。

Astro・OpenAI Sites・Codex CLIによる公開経路は現行構成にない。DocsifyとDOMPurifyはjsDelivrを使うため完全offline閲覧は未対応。添付ファイル同期は未対応。公開は閲覧制限なしの構成であり、非公開repositoryでもPagesの閲覧は非公開にならない。

## iOSの初期実装

`ios/project.yml`をXcodeGenで生成する独立したiOS 17以降のSwiftUIアプリ。Pagesへは配信しない。

- `ios/Sources/ArticleClient.swift`: 専用一覧v1の検証、HTTPS取得、リダイレクト拒否、15秒の要求Timeout、最大3回の限定Retry、本文hash照合。
- `ios/Sources/ArticleLinks.swift`: Frontmatter除去、コード内を除くWiki Link変換、一覧内のID・path・title・alias解決。
- `ios/Sources/StudyStore.swift`: 独立した記録JSONのatomic保存、復元検証、monotonic uptimeでの計測区間。
- `ios/Sources/StudyApp.swift`: 一覧・検索・フォルダ・本文・履歴・設定、画面とアプリ状態による計測制御。本文はMarkdownUI。下部タブは記事・聴く・検索・フォルダ・設定で、履歴は設定のNavigationStack内で開く。
- `ios/Sources/AudioLibrary.swift`: 許可された制作物フォルダをbookmarkで保持し、起動/アクティブ復帰/手動操作で同期。管理JSONのarticleID/trackIDで自動紐付けと差し替えを行い、playlistIDとtrackIDsの番組一覧も同期する。Application Supportへコピーし、音声一覧と位置をatomic保存。学習記録バックアップとは独立。
- `ios/Sources/TrackPlayer.swift`: AVAudioPlayerでナレーションとBGMを再生。倍速、位置保存、AudioSessionとMediaPlayerによるバックグラウンド・ロック画面操作、割り込み停止。
- `ios/Sources/AudioView.swift`: 番組タイルと音声を統合したListeningHome、管理用番組一覧/詳細、専用再生画面、聴く/番組のミニプレイヤー、設定内の音声取り込みを担当。記事からは再生画面を直接開き、別の記事の音声なら再生を開始する。入力形式はios/AUDIO_IMPORT.md。

音声は制作側で事前生成し、iCloud Drive等のファイルを利用する。アプリによる生成API呼び出し、iCloudフォルダ自動監視、音声のPages公開は行わない。原本は変更せず、同期成功後に端末内コピーと一覧を更新する。

プロジェクト生成・ビルド・テストはMacで行う。現時点の制約と手順は[ios/README.md](ios/README.md)を参照する。

- `ios/Sources/RadioSession.swift`: 番組Schema、順番のスナップショットと再開状態、ナレーション/インターバル/終了の遷移、無音PCM。TrackPlayerが音声終了のdelegateで次の区間を進める。BGMは別プレイヤーで継続し、pauseと番組終了時に停止する。番組と端末の間隔設定、再開状態は音声一覧JSONに保存する。

- `ios/Resources/Assets.xcassets`: 抽象的な1024pxアイコン。project.ymlのResourcesとAppIcon設定からビルドへ取り込む。署名Teamは端末導入時にローカル指定し、共有設定へ固定しない。

- `ios/Sources/LibraryViews.swift`: ホーム・日替わり選出・保存一覧・階層フォルダ・お気に入り/コレクション管理。フォルダ開閉はUserDefaults。
- `ios/Sources/StudyDesign.swift`: 明暗対応の共通色、タグの折返しLayout、MarkdownUIの本文Theme。
- `StudyBackup`のoptional favorites/collectionsは記事IDで個人整理を保存し、旧v1復元とatomic保存・破損保護を維持する。

- 記事カードとカルーセルはcatalogのタイトル・metadataだけで描画し、本文抜粋の表示/自動取得は行わない。Libraryは記事を開いた時と明示的な全文検索時に本文を取得し、hash照合後ID+hashでメモリcacheする。hash検証した本文をOfflineArticlesへ永続保存する。

- `ios/Sources/ArticleCarousel.swift`: ホームの正方形記事タイルとLazyHStack横スクロール、viewAlignedスナップ。Dynamic Typeでカード寸法を拡大する。本文は取得せずcatalogとStudyStore/AudioLibraryの状態を使う。

- `ios/Sources/HistorySummary.swift`: sessionsを記事IDごとにまとめ、合計秒数と最新の区間終了時刻を計算する表示用集計。保存済みsessionを変更しない。

- `StudyApp`の各タブを`PlayerTabContent`で包み、NavigationStackと`AudioMiniPlayer`を間隔0のVStackに配置。再生バーの実際の高さを確保してから残りを画面に割り当て、遷移した記事本文や読了ボタンが再生バーの下へ入り込むことを防ぐ。共有`TrackPlayer`の状態でタイトル・進捗・再生/一時停止を表示。

- `AudioTrack.listened`はoptional Boolとして既存音声index v1に保存。再生終了delegateの成功通知で、現在のlocalFileが一致する音声だけ聴取済みにする。`AudioIndex.listenedCount`が番組のtrackIDsを集計する。音声hashが変わる再取り込みでは状態をリセットし、台本/metadataのみの変更は維持する。学習記録の読了/時間やbackupには含めない。

- 番組の個人編集はAudioLibraryのatomic保存で確定しAudioLibraryModelから公開する。index v1のoptional editedProgramIDs/deletedProgramIDsで旧保存形式との互換を保つ。編集済みIDと削除済みIDは番組同期から除外し、programs配列の表示順を維持して新番組を末尾へ追加。端末保存の番組だけ空配列を許可し、制作JSONとRadioSessionは非空を検証する。編集操作は音声・曲間上書き・再生スナップショットを保持する。

- アプリ配信catalogのtypeは拡張可能な分類文字列（空なら未分類）として保持する。iOS画面はtypeで取得可否を決めない。ローカルVault同期は任意のtype・未指定を許可し、未指定を空文字列へ正規化する。配信v1ではtypeの文字列型を必須とする。

- `ios/Sources/SearchView.swift`: SearchNavigationがタブ選択と検索条件を共有し、記事のタグや保存/フォルダ一覧から条件付きで検索タブを開く。記事はmetadataと明示操作で取得した本文、音声はタイトル/声/台本と関連記事metadata、番組はタイトルと構成音声/関連記事metadataを検索する。記事条件は関連する記事を持つ音声/番組へ適用し、番組は一致する構成音声が1本以上あれば候補にする。読了と聴取状態は各対象の保存状態を用いる。本文取得は直列でLibraryのhash照合とID+hashキャッシュを使い、取消後の結果反映を防ぐ。永続検索索引は保持せず、保存済み本文も明示操作の本文検索で使用する。
- `StudyBackdrop`と`StudyTileSurface`: 共通色と静的な局所光・細い縁を用いる。本文の背景は単色。タブ内部のList/Formは標準スクロール背景を隠し共通背景を見せる。Reduce Transparency/Increase Contrastでタイルの装飾と縁を調整し、常時アニメーションを導入しない。

- ピックアップは各記事の順位hashを1回計算して並べ替える。ArticleListは記事集合・日付・手動入れ替え回数をtaskの識別値にし、別タスクで選出した結果をStateへ保持する。画面再評価ごとの選出を避け、取消された古い選出結果は反映しない。

- `StudyTheme`（`StudyDesign.swift`）はLiving Aurora/Pulse Neon/Blue Cosmos/Windows 98の色・角丸・Markdown Themeを提供。AppのAppStorageで保存した選択を`EnvironmentValues.studyTheme`に渡し、各画面が参照する。`ThemeSettingsView`は全4種のプレビューと表示モード選択。`StudyAppearance`は端末/ライト/ダークを扱い、Windows 98は明るい表示を固定。設定はUserDefaultsで、学習記録backupと独立。星空と回路模様は静的Canvas、星のseedは固定。本文はテーマごとの単色面、List/Formとsheetは共通背景・行色、ミニプレイヤーは共通surfaceを使用する。

## Learnleaf ロードマップ拡張（2026-10-06）

- SearchConditions/SearchPreferencesは検索対象・条件・並び順・履歴12件・名前付き条件をUserDefaultsへ保存。SearchEngineは画面評価で1回だけ計算し、記事/音声ID辞書と条件集合を再利用。条件変更は全文検索の世代を無効化して取消後の結果反映を防ぐ。
- AudioLibrary.prepareTracksは保存状態を参照せずJSON・音声decode・hash・台本を検証し、refreshの別タスクで実行。importPreparedは最新indexで記事IDの不変性・番組参照を再検証して確定。位置/聴取/個人番組編集を保持。確定時のファイルコピー/atomic保存はメイン側、全音声Data保持も継続。
- RelatedContentは共通タグ数で関連記事を選出し、自己記事を除く。番組のtrackIDとarticleIDから記事/コレクションに関連する番組を解決。記事・再生画面・コレクションを既存NavigationStackで接続。
- ピックアップ対象の単一タグはUserDefaults。カードの長押しで保存sheetを開け、新規コレクションの作成と記事追加は一回のatomic記録保存で確定。
- OfflineArticles actorはApplication Support/StudyApp/offlineに検証済みcatalogとhash名の本文をatomic保存。読取時もcatalog/path/hashを検証。Libraryはメモリ→同hashの端末本文→HTTPSの順で取得し、通信不可の起動時のみ保存catalogへfallback。JSON/hash不正をofflineで隠さない。全記事保存は明示操作・取消・失敗件数付き。保存容量は旧版本文も含む全体、保存記事数は現在catalogの同hashだけを数える。削除は記録/音声を保持し取得中は拒否。
- StudyRecordMergeは既存v1 JSONを検証して学習区間IDをunion。同一IDの異なる区間は統合を拒否。読了はOR、最終閲覧は新しい日時、お気に入りとcollection articleIDsはunion、同collection名はローカル優先。削除の伝播や自動iCloud同期は行わない。明示確認後に現在記録へatomic保存。
