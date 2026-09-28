---
status: current
audited: 2026-09-28
---

# 現行 Study の機能と互換性インベントリ

## 調査範囲

現行コード、生成 JSON、テスト、Git 履歴、および代表的な Markdown を一次情報として確認した。主な対象は `build_note_index.py`、`docs/reader-tools.js`、`docs/obsidian-wikilinks.js`、`docs/index.html`、`docs/training/`、`docs/_article-master.json`、`docs/_note-index.json`、`docs/バックアップ・復元.md`、`tests/` である。

2026-09-28 時点のコンテンツ実測値は次のとおり。

| 項目 | 実測値 |
| --- | ---: |
| Markdown | 343 ファイル / 約 2.81 MiB |
| `training/` 配下 | 12 ファイル |
| YAML Frontmatter 導入済み | 0 ファイル |
| Wiki Link | 361 箇所 |
| Markdown task item | 769 箇所 / 14 ファイル |
| 標準 Markdown link | 18 箇所 |
| Markdown / Obsidian 画像埋め込み | 0 箇所 |
| HTML `<img>` | 6 箇所（説明用コードを含む） |
| article master | version 1、343 記事、UUID 343 個すべて一意 |
| 同名 filename stem | 4 組 |

## 現行アーキテクチャ

`docs/` を静的配信し、Docsify がブラウザーで Markdown を取得して描画する。Python スクリプトが filename stem と path から二つの JSON を生成し、ブラウザー JavaScript が検索、リンク解決、学習状態を追加する。サーバー、DB、npm build、CI/CD はない。

ルートサイトと `docs/training/` は CSS と reader tools を共有する。研修サイトは `pathPrefix: 'training'` で全体索引をローカルルートへ変換し、バックアップ導線とパスワード画面を表示しない。

## 閲覧機能

| 機能 | 現行挙動 | 再構築時の扱い |
| --- | --- | --- |
| Markdown 表示 | Docsify 4 を jsDelivr から実行時取得 | 維持。ビルド時 HTML 生成へ変更 |
| レスポンシブ UI | 600px / 1100px を境にナビゲーションと sidebar を変更 | 同等機能を維持 |
| テーマ | 5テーマ。`study-notes:theme` に番号を保存 | UI preference として移行対象外、再設定可 |
| sidebar | 表示切替と 220–520px の幅調整 | 維持候補。幅は user preference |
| 記事ヘッダー | path と filename stem を表示。タイトルをコピー可能 | Frontmatter title を表示し、path は補助情報へ |
| 目次 | h1–h4 から drawer を生成 | 維持 |
| 重複見出し | 重複時のみ ASCII の `heading-N` を追加 | テストケースを引き継いでビルド時に安定化 |
| 検索 | filename stem の部分一致のみ | title、tags、本文を最低条件に拡張 |
| 履歴移動 | browser history の戻る / 進む、ホーム | 維持 |
| コードコピー | click / keyboard、Clipboard API と fallback | 維持 |
| 推定読了時間 | 500文字/分、最低1分 | 表示機能として維持候補 |
| Wiki Link | `[[note]]`、alias、見出し、画像構文を変換 | 互換 parser を維持。標準 Markdown link を優先 |
| パスワード画面 | JS 内の平文文字列と sessionStorage | セキュリティ機能として移植しない。必要なら hosting 層で設計 |

## 学習状態

### 記事 progress

localStorage key は `study-notes:article:<legacy UUID>`。値は JSON 文字列である。

```json
{
  "version": 1,
  "completed": false,
  "completedUpdatedAt": null,
  "learningSeconds": 0,
  "lastViewedAt": null
}
```

- 記事表示時に `lastViewedAt` を ISO 8601 文字列で更新する。
- 未読了、document visible、window focus の三条件を満たす間だけ秒数を加算する。
- 1秒 interval、ページ遷移前、blur、visibility change、pagehide で flush する。
- 読了中は timer を止める。未読了に戻すと再開する。
- 時間は時・分・秒で手動上書きできる。
- ホームでは home と backup page を除く全記事を分母にして読了率と合計時間を計算する。現在は `type` がないため Wiki 相当の記事もすべて対象になる。

### checklist

checked の項目だけを値 `"true"` として保存する。

```text
study-notes-checklist::<canonical path>::<item text>::<same-text occurrence>
```

path 移動または task 文言変更で連続性を失う。移行時は legacy path、正規化した文言、同文言の出現番号を使って新 article ID 配下へ対応付ける必要がある。

### UI preference と session

| key | 内容 | 学習バックアップ対象 |
| --- | --- | --- |
| `study-notes:theme` | テーマ番号 | 対象外 |
| `study-notes:sidebar-width` | desktop sidebar 幅 | 対象外 |
| `study-notes:authenticated` | sessionStorage の表示ゲート通過フラグ | 対象外 |

## バックアップ version 1

export は学習 progress と checklist の localStorage 値を、そのまま文字列として `records` に入れる。

```json
{
  "format": "study-notes-backup",
  "version": 1,
  "exportedAt": "2026-09-28T00:00:00.000Z",
  "records": {
    "study-notes:article:<uuid>": "{...}",
    "study-notes-checklist::<path>::<text>::0": "true"
  }
}
```

復元は上書きとマージを持つ。マージ時は読了状態を `completedUpdatedAt` が新しい側から選び、学習時間は重複加算を避けるため大きい方、最終閲覧日時は新しい方を採用する。日時がない旧データでは読了済みを優先する。新実装はこの意味を互換仕様としてテストで固定する。

## Content と link の実態

- 現行 title と検索 key は filename stem で、表示 title と identity が分離されていない。
- Frontmatter はまだ存在しないため、343件すべてが legacy compatibility 対象である。
- 同名 stem は `DynamoDBとは？`、`アンジェリカはまかわ`、`大空と大地のなーさりぃ大森駅前園`、`🌟AWS基礎について` の4組。
- `にじいろ保育園.md` では filesystem 上の NFC 表現と既存 master の NFD 表現が異なる。現行 generator は raw path 文字列で UUID を対応付けるため、再生成だけで別 UUID を発行し得る。移行 manifest は Unicode normalization を比較に使いつつ、元の path bytes / legacy ID を保持する必要がある。
- Wiki Link は note name、明示 path、alias、heading を使用している。
- 現行 resolver は同名候補があると console warning を出すが、最短・最浅 path を自動選択する。これは誤リンクになり得る。
- path を含む一部 Wiki Link には旧 repository 名を含む表記がある。移行 parser は実在 path と一致するか監査し、文字列置換だけで修正しない。
- 標準 Markdown link は主に外部 URL。現時点で `.md` を直接指す relative link は検出されなかった。
- 添付画像の実資産は確認できず、検出した `<img>` の多くは教材中のコード例である。将来の attachments は相対 path を基準に設計する。

## 自動テストと不足

存在するテストは Node 標準機能による次の2本だけ。

- password gate の成功・失敗・sessionStorage 再利用。
- 重複見出し ID、code fence 除外、既存 explicit ID の維持。

未テストなのは index generator、Frontmatter、Wiki Link 全構文、曖昧 link、progress timer、backup validation / merge、checklist、検索、root / training のブラウザー動作である。再構築では domain と migration を DOM から分離し、まず純粋関数としてテストする。

## 移行で失ってはいけない契約

1. 343 個の legacy UUID と対応する新 article ID を一対一に記録する。
2. version 1 backup を読み込み続け、未知・未対応 record を黙って捨てない。
3. progress の4フィールドと checklist の意味を維持する。
4. timer の focus / visibility / pagehide flush と二重加算防止を維持する。
5. 361 箇所の Wiki Link を監査し、曖昧候補を自動で誤決定しない。
6. root と training の公開境界を明示的な content type / collection rule に置き換える。
7. legacy サイトを rollback 可能なまま、新サイトを別 URL で並行検証する。
