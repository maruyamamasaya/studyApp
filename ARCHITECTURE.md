---
status: active
updated: 2026-09-29
---

# アーキテクチャ

## 全体像

旧サイトは `docs/` の静的ファイルを Docsify が実行時に描画する。新 Study App は外部 Obsidian Vault を記事の唯一の正本とし、`content/notes/` へ生成した公開ミラーを Astro が build 時に再検証・HTML化し、`dist/` を OpenAI Sites で配信する。旧サイトは参照用として維持する。

```text
Obsidian Vault / study・wiki（唯一の正本）
  │ scripts/sync-obsidian-content.mjs（検証付き、一方向同期）
  ▼
content/notes/**/*.md（Git / build 用の生成ミラー、直接編集禁止）
  │ Frontmatter / ID / path validator
  ├─► generated/article-master.json / link-index.json / search-index.json
  └─► Astro static build ──► dist/
                                │
                                └─► OpenAI Sites（一覧 / training / articles/:id）

旧外部ノート同期
  │ rsync（手動同期手順）
  ▼
docs/**/*.md ── build_note_index.py ──► _note-index.json
       │                         └────► _article-master.json
       ▼
静的ホスト ──► index.html / training/index.html
                   │
                   ├─ jsDelivr から Docsify を取得
                   ├─ Markdown と JSON を fetch
                   └─ ブラウザーで描画・閲覧状態を localStorage に保存

```

## 新 Study App（Phase 1）

| 場所 | 責務 |
| --- | --- |
| 外部 Vault `study/**/*.md` / `wiki/**/*.md` | 記事の唯一の正本。Obsidianで作成・編集する |
| `content/notes/**/*.md` | Git / build / Sites向けの生成ミラー。filename stemとFrontmatter IDを一致させ、直接編集しない |
| `scripts/sync-obsidian-content.mjs` | Vault の `study/` / `wiki/` を検証し、同期管理外ファイルを上書きせず `content/notes/` へ反映する |
| `generated/obsidian-sync-manifest.json` | 同期元相対 path、同期先、ID、内容 hash。安全な更新と明示 prune の境界 |
| `app/src/content.config.ts` | Astro content collection の Frontmatter schema と表示用正規化 |
| `app/src/domain/article.mjs` | parser、ID / path invariant、tags / aliases、link index の純粋 domain |
| `app/src/domain/study-progress.mjs` | 学習状態version 2の検証、記事ID単位のlocalStorage repository、集計、backup merge |
| `scripts/build-content-index.mjs` | build 前検証と `generated/` の再生成 |
| `app/src/markdown/` | Wiki Link の build-time 解決と raw HTML のコード表示化 |
| `app/src/pages/` | ホーム、研修一覧、ID 固定の個別記事 route |
| `app/src/layouts/BaseLayout.astro` | 共通ヘッダー、記事 path から生成する階層サイドバー、5テーマの選択・初期適用・localStorage 保存 |
| `app/src/components/StudyProgressPanel.astro` | 記事の読了操作、アクティブ閲覧時間の計測、最終閲覧日時の保存 |
| `app/src/components/LearningDataTools.astro` | `study`記事の読了数・合計時間と、version 2 backupの保存／復元 |
| `app/src/styles/global.css` | Standard / Wiki / Living Aurora / Blue Cosmos / Pulse Neon のデザイントークンとレスポンシブ表示 |
| `migration/phase1-samples.json` | Phase 1で使った履歴fixture。現行同期・buildには使用しない |
| `dist/` | Astro の静的生成結果。OpenAI Sites の公開対象 |

Wiki Link は exact path、title、alias、filename の順で候補を評価する。同順位で複数候補が残る場合はリンクを生成せず「リンク曖昧」、候補がなければ「リンク未解決」と表示する。標準 Markdown link は通常の link node として優先して保持する。

Markdown の raw HTML node は rehype 段階で `code.raw-html-example` に変換する。記事本文から `script`、event handler 付き要素などを実行可能な DOM として出力しない。

## 主要コンポーネント

| 場所 | 責務 |
| --- | --- |
| `docs/index.html` | ルートサイトの HTML、Docsify 設定、パスワード画面、共有スクリプト読込 |
| `docs/training/index.html` | `training/README.md` をホームにする研修サイト。共有資産へ相対パスで接続し、研修用設定を上書き |
| `docs/favicon.svg` | ルートサイトと研修サイトで共有するサイトアイコン |
| `docs/**/*.md` | 公開する記事コンテンツ。Obsidian Wiki リンクを含む |
| `docs/styles.css` | 両サイトのテーマとレスポンシブ UI |
| `docs/reader-tools.js` | 検索、ナビゲーション、テーマ、目次、学習進捗、チェックリスト、バックアップ等のクライアント機能 |
| `docs/obsidian-wikilinks.js` | Wiki リンクと画像埋め込みを Docsify 用リンクへ変換 |
| `docs/unique-heading-ids.js` | Markdown 描画前に重複見出しへ衝突しない ASCII ID を追加 |
| `docs/password-gate.js` | ルートサイトのセッション単位の表示ゲート（認証基盤ではない） |
| `build_note_index.py` | Markdown 一覧を走査し、名前解決索引と記事 ID マスターを生成 |
| `tests/*.test.js` | Node 標準モジュールだけで一部ブラウザースクリプトをテスト |

## サイト境界

### Study Notes ルート

`docs/index.html` は `📚 Study Notes Hub.md` をホームにする。最初に `password-gate.js` が画面を覆い、同一タブの sessionStorage に通過状態を保存する。その後の Markdown と静的資産自体は通常のクライアント配信なので、機密性は提供しない。

### 研修サイト

`docs/training/index.html` は `README.md` をホームにし、`READER_TOOLS_CONFIG` で親ディレクトリの索引・記事マスター・共有スクリプトを利用する。`pathPrefix: 'training'` により全体索引内のパスとローカルルートを変換する。バックアップ導線は非表示で、パスワード画面もない。

## データと状態

サーバー側永続層や DB schema はない。

- コンテンツ: Git 管理された Markdown。
- `_note-index.json`: ノート名から拡張子なしパスの配列への生成索引。同名記事は複数候補を持てる。
- `_article-master.json`: 記事パス、表示タイトル、UUID の生成一覧。既存パスの UUID は再生成時に維持され、ブラウザー保存状態のキーになる。
- localStorage: 記事進捗、学習時間、チェックリスト、テーマ、サイドバー幅。
- sessionStorage: パスワード画面の通過フラグ。

バックアップは対象となる学習記録だけをバージョン付き JSON としてクライアント内で export/import する。外部サービスへの同期はない。

## 表示データフロー

### 旧 Docsify

1. ブラウザーが対象の `index.html` と共有資産を取得する。
2. Docsify とプラグインが初期化される。
3. ルートに対応する Markdown を Docsify が取得する。
4. unique-heading プラグインが重複見出しを処理し、Wiki link プラグインが `_note-index.json` を使ってリンクを解決する。
5. Docsify が HTML を描画し、reader tools がナビゲーションと localStorage 上の状態を接続する。

### 新 Study App

1. `npm run content:build` が `content/notes/**/*.md` を列挙し、Frontmatter、ID、filename、path を検証する。
2. 正規化した記事から `generated/` の article master、link index、search index を作る。
3. Astro content collection が同じ Frontmatter schema を検証し、Markdown を HTML 化する。
4. Wiki Link は link index から build 時に解決し、生 HTML はコード表示へ変換する。
5. Astro がホーム、研修一覧、記事 ID route を `dist/` に書き出す。ブラウザーでは保存済みテーマを描画前に適用し、テーマ選択を localStorage に保存する。
6. 記事 route は新IDをkeyに学習状態を読み、画面がactiveかつ未読了の間だけ学習時間を加算する。サイドバーは`study`記事だけを読了率の分母にする。
7. Sites は生成済みの静的資産を配信する。

## コンテンツ同期・生成

新 Study App の記事正本は `C:\Users\m-maruyama\Development\Document organization` の Obsidian Vault で、対象は `study/**/*.md` と `wiki/**/*.md` に限定する。同期は Vault → `content/notes/` の一方向で、空ファイルは下書きとして保持・除外する。`vault:prepare` は manifest の hash と一致する同期済みファイルに限って削除も反映し、Vaultに存在しないミラー記事や同期後の直接変更を拒否する。Templater が folder ごとの `type`、ID filename、`created` を発行する。

手動同期の記録された流れは `git pull --rebase`、外部ディレクトリから `docs/` への Markdown の rsync、差分確認、`python3 build_note_index.py`、commit/push である。生成スクリプトはホームページを Wiki リンク名前解決の対象から除外するが、記事マスターには含める。

## 配信・外部依存

- リポジトリにはサーバー、コンテナ、IaC、workflow がない。
- Docsify 4 の JavaScript と Vue テーマ CSS を jsDelivr CDN から取得する。
- `.nojekyll` がある。GitHub Pages での静的公開を示唆するが、ホスティング設定は確認不能。
- 新サイトの配信設定は `.openai/hosting.json`、公開対象は `dist/` とする。Phase 1 は一覧・研修一覧・代表記事7件を OpenAI Sites へ既存の非公開範囲で配信する。
- 旧 Docsify 配信物は `docs/` に維持し、新サイトの受入条件が揃うまでは置き換えない。
- API 定義、DB migration、環境変数設定はない。

## テスト境界

旧 Docsify の `tests/password-gate.test.js` と `tests/unique-heading-ids.test.js` は従来どおり Node の単体スクリプトとして維持する。新 Study App は Node test runner で domain と生成 HTML を検証し、`npm run check` が test → content / Astro build → output test を順に実行する。Python 生成器は旧 `docs/` の検証用として残す。

## 関連資料

- 現状と制約: [`CURRENT.md`](CURRENT.md)
- 同期コマンド詳細: [`docs/md更新用コマンド.md`](docs/md更新用コマンド.md)
- 研修記事の目次: [`docs/training/README.md`](docs/training/README.md)
- 構成判断の記録: [`decisions/ADR-001-static-docsify-and-generated-indexes.md`](decisions/ADR-001-static-docsify-and-generated-indexes.md)
