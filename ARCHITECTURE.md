---
status: active
updated: 2026-09-15
---

# アーキテクチャ

## 全体像

ビルド済みアプリを配信する構成ではなく、`docs/` の静的ファイルをブラウザーへ配信し、Docsify が実行時に Markdown を取得・描画する構成である。

```text
外部ノート（リポジトリ外、詳細不明）
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

1. ブラウザーが対象の `index.html` と共有資産を取得する。
2. Docsify とプラグインが初期化される。
3. ルートに対応する Markdown を Docsify が取得する。
4. unique-heading プラグインが重複見出しを処理し、Wiki link プラグインが `_note-index.json` を使ってリンクを解決する。
5. Docsify が HTML を描画し、reader tools がナビゲーションと localStorage 上の状態を接続する。

## コンテンツ同期・生成

手動同期の記録された流れは `git pull --rebase`、外部ディレクトリから `docs/` への Markdown の rsync、差分確認、`python3 build_note_index.py`、commit/push である。生成スクリプトはホームページを Wiki リンク名前解決の対象から除外するが、記事マスターには含める。

## 配信・外部依存

- リポジトリにはサーバー、コンテナ、IaC、workflow がない。
- Docsify 4 の JavaScript と Vue テーマ CSS を jsDelivr CDN から取得する。
- `.nojekyll` がある。GitHub Pages での静的公開を示唆するが、ホスティング設定は確認不能。
- API 定義、DB migration、環境変数設定はない。

## テスト境界

`tests/password-gate.test.js` と `tests/unique-heading-ids.test.js` は Node の `assert`、`fs`、`vm` を使う単体スクリプトである。package script や共通 test runner はない。Python 生成器は実行結果の差分確認が主な検証方法である。

## 関連資料

- 現状と制約: [`CURRENT.md`](CURRENT.md)
- 同期コマンド詳細: [`docs/md更新用コマンド.md`](docs/md更新用コマンド.md)
- 研修記事の目次: [`docs/training/README.md`](docs/training/README.md)
- 構成判断の記録: [`decisions/ADR-001-static-docsify-and-generated-indexes.md`](decisions/ADR-001-static-docsify-and-generated-indexes.md)
