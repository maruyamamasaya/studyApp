# アプリ向け記事配信仕様 v1

更新: 2026-10-02

この仕様は、Web版とは独立したiOS等のアプリが、共通の記事をHTTPSで取得するための契約である。記事の正本はObsidian Vaultで、アプリ向け一覧とMarkdownをGitHub Pagesへ配信する。学習記録やアプリの画面は配信対象に含めない。

生成処理とWindows上のHTTP検証は実装済み。今回の作業ではcommit/pushを行っていないため、新しい配信URLは次の公開後に利用可能になる。iOSの初期コードはios/に追加済み。Macでのビルドとテストは未実行。

## 1. 配信先

公開後のサイト基準URL:

```text
https://maruyamamasaya.github.io/studyApp/
```

公開後の一覧URL:

```text
https://maruyamamasaya.github.io/studyApp/app-articles.v1.json
```

Markdownは一覧のpathを基準URLへ結合して取得する。pathはサイトルート相対であり、JSONファイルの文字列へ単純に付け足さない。Docsify用の`#/...`を含む画面URLは使用しない。

本文URLの例:

```text
https://maruyamamasaya.github.io/studyApp/wiki/anken001/20261001-171535.md
```

GitHubのAPIやGit clone/pullは使わず、公開ファイルを読む。GitHub Token、APIキー、ログインは不要。配信内容は一般公開であり、個人用アプリから利用しても非公開にはならない。

## 2. 一覧の形式

```json
{
  "schemaVersion": 1,
  "revision": "0000000000000000000000000000000000000000000000000000000000000000",
  "articles": [
    {
      "id": "20261001-171535",
      "title": "RAGの処理フロー",
      "path": "wiki/anken001/20261001-171535.md",
      "type": "study",
      "tags": ["RAG", "API", "anken001"],
      "aliases": [],
      "created": "2026-10-01 17:15:35",
      "contentHash": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  ]
}
```

hashのゼロ列は形式説明用であり、実値ではない。文字列はUTF-8で配信する。一覧にはVaultのstudy/wiki配下で検証済みの全記事を含め、空の下書き、ホームなどの生成ページ、Vaultの絶対パス、学習記録は含めない。

| 項目 | 型 | 意味 |
| --- | --- | --- |
| schemaVersion | 整数 | 現行は1。未対応の版は読み込みを止める |
| revision | 文字列 | 一覧全体の変更を判定する64桁の小文字16進hash |
| articles | 配列 | idの昇順の記事一覧。0件も有効 |
| id | 文字列 | YYYYMMDD-HHmmss形式の安定ID。学習記録の紐付けに使う |
| title | 文字列 | 表示用の非空タイトル。原本にタイトルがない場合は「未設定」 |
| path | 文字列 | study/またはwiki/で始まる本文の相対パス |
| type | 文字列 | 任意の種別。配置フォルダとは独立。原本で空欄・省略・nullの場合は空文字列を配信する。自由な種別の受け入れには対応済みアプリへの更新が必要 |
| tags | 文字列配列 | 検索・絞り込み用。空配列可 |
| aliases | 文字列配列 | 記事の別名。内部リンクの解決用。空配列可 |
| created | 文字列 | 原本の作成日時。YYYY-MM-DD HH:mm:ss。タイムゾーンを含まず、更新判定には使わない |
| contentHash | 文字列 | 本文の整合性・更新判定用hash。計算規則は次節 |

idとpathはそれぞれ重複を許可しない。記事の移動ではIDを維持し、取得先だけを最新pathへ変更する。未知の追加フィールドはクライアントが無視できるようにする。必須項目の意味・型を変更する場合は、新しいschemaVersionと配信ファイルを用意し、v1を黙って変更しない。

revisionは、ID順に並べたarticlesを生成側のJSON.stringifyでコンパクトに直列化し、UTF-8でSHA-256を計算したもの。クライアントは不透明な変更識別子として比較し、独自のJSON直列化で再計算しなくてよい。変更のない再生成で値を変えないため、生成日時は付けない。

## 3. 本文hashの規則

contentHashはSHA-256の64桁小文字16進文字列で、次の手順で計算する。

1. 取得したMarkdownをUTF-8の文字列として読む。
2. CRLF（Windows形式の改行）をLFへ置換する。
3. その文字列をUTF-8へ変換し、SHA-256を計算する。

Frontmatterを含むファイル全体が対象。空白、末尾改行、日本語のUnicode表現はそれ以上正規化しない。単独のCRも変換しない。Git checkoutによるLF/CRLFの差を吸収し、Windowsで生成した一覧をLinuxのGitHub Pagesで配信できるようにする。ネットワークの生バイト列を正規化せずhash化する方式ではない。

Frontmatterは本文hashの対象だが、アプリの本文画面では除く。タイトルやタグは一覧から表示する。実装時は日本語、末尾空白、改行を含む実データで同じhashになることを確認する。

## 4. クライアントの取得手順

1. 一覧をGETし、HTTP成功、JSON形式、schemaVersion、必須項目、ID重複を検証する。
2. 一覧から記事を選び、pathの各区間をURLエンコードして基準URLと結合する。
3. 本文をGETし、HTTP成功とcontentHashを確認する。
4. Frontmatterを本文から除き、アプリの描画部品で表示する。
5. 読了・学習時間は記事IDへ紐付け、アプリ側に保存する。

pathはURLエンコード前の相対パスである。日本語、空白、#、%などを含む場合は区間ごとに一度エンコードする。先頭/、空区間、.、..、バックスラッシュ、任意の絶対URLは許可しない。任意の内部リンクを本文取得URLとして直接実行せず、一覧で解決する。

本番はHTTPSで取得し、HTTPはローカル検証に限定する。基準URLのoriginと配下を取得範囲とし、未許可の接続先へリダイレクトを追わない。タイムアウトを設け、成功したHTTP応答でも本文hashを検証する。オフライン保存は必須ではない。

## 5. 更新・移動・削除

| 変更 | 一覧の変化 | クライアントの扱い |
| --- | --- | --- |
| 本文編集 | contentHashとrevisionが変わる | 次の取得で新本文を確認 |
| タグなどのmetadata変更 | revisionが変わる | 一覧の表示・検索情報を更新 |
| 同じIDの記事移動 | pathとrevisionが変わる | 新pathへ取得先を変更。学習記録は維持 |
| 記事削除 | 一覧からIDが消える | 掲載を外す。学習履歴は別に保持 |
| 変更なしの再同期 | 一覧全体が同じ | 不要な更新と履歴変更をしない |

一覧取得失敗や不正JSONを空一覧として扱わない。正常に取得した完全な一覧だけで掲載状態を更新する。正常なarticles: []は公開記事0件を表す。

CDNのキャッシュや公開切り替えで一覧と本文の版がずれる可能性がある。hash不一致や404では一覧と本文を有限回数再取得し、解消しなければ「記事更新中または取得失敗」として再試行操作を提示する。無限再試行や、不一致本文の黙認をしない。GitHub Pages上の複数ファイル取得が一つのトランザクションになるとは想定しない。

## 6. 生成と検証コマンド

これまでと同じコマンドで、記事同期に加えてapp-articles.v1.jsonを生成する。

```powershell
npm run vault:prepare
```

公開時は既存の手順を使う。

```powershell
npm run vault:publish
```

生成物はdocs/app-articles.v1.json。Web用metadataは別ファイルのまま維持し、Docsifyは新しいJSONへ依存しない。本文もVaultの原文を維持する。

ローカルHTTP検証は、別の端末でnpm run devを起動した状態で次を実行する。

```powershell
npm run app:verify -- http://127.0.0.1:8000/
```

新しいファイルを公開した後の検証:

```powershell
npm run app:verify -- https://maruyamamasaya.github.io/studyApp/
```

app:verifyは読取専用。全記事を順番に取得し、一覧の形式、HTTP成功、本文hashを確認する。本文ごとの詳細ログは成功時に出さず、失敗時には対象と原因を表示して非0で終了する。各要求は15秒まで待ち、全記事の取得を含むため総時間は記事数に依存する。

## 7. 実装済みと残る作業

Windowsで実装・検証済み: 配信一覧の生成、安定したhash、通常同期への組み込み、再生成・更新・移動・削除のテスト、HTTP取得検証。

次の公開時に確認する事項: Pages上で一覧と本文が取得できること、公開後のapp:verifyが成功すること。

iOSの通信・Markdown描画・内部リンク・学習記録・バックアップの初期コードを追加した。iOS 17以降、SwiftUI、MarkdownUI、記録JSONを採用。Macでの検証と残課題は[iOS確認手順](ios/README.md)を参照する。
