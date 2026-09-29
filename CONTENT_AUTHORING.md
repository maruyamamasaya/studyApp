# Markdown 記事の追加と公開

## 配置場所とファイル名

新しい記事は Obsidian Vault の次の2フォルダで作成する。ここが記事の唯一の正本である。`content/notes/**/*.md` は Git / Sites で再現可能にする公開用ミラーであり、直接編集しない。旧 Docsify 用の `docs/` にも新規記事を置かない。

学習記事:

```text
C:\Users\m-maruyama\Development\Document organization\study\20260929-142430.md
```

Wiki 記事:

```text
C:\Users\m-maruyama\Development\Document organization\wiki\20260929-142430.md
```

filename stem と `frontmatter.id` は必ず一致させる。ID は Asia/Tokyo の作成時刻を `YYYYMMDD-HHmmss` で表す。同じ秒の ID が既にある場合は未使用の秒まで進める。既存 ID は変更しない。

## Frontmatter

```md
---
id: 20260929-142430
title: ゼロトラストの基本
type: study
tags:
  - security
  - zero-trust
created: "2026-09-29 14:24:30"
updated:
aliases:
  - Zero Trust
---

# 概要
```

- `title` は空欄でもよく、その場合の画面表示は `未設定` になる。
- `type` の初期値は `study` または `wiki`。未知の値は Phase 1 では warning として扱う。
- `tags` は必須の配列で、空なら `[]` とする。前後空白、空要素、重複は生成時に除去される。
- `aliases` は任意の配列。前後空白、空要素、重複、title と同じ値は除去される。
- `created` は Asia/Tokyo のローカル時刻。テンプレートでは YAML parser の差を避けるため引用符で囲む。既存の引用符なし YAML 日時も同じ表示値として受理する。
- `updated` は Obsidian テンプレート互換の任意項目。空欄でも閲覧でき、現時点では記事 ID や並び順に使わない。

## 追加から公開まで

1. Obsidian で `study/` または `wiki/` の直下・配下に新規 Markdown を作る。Templater が対応テンプレートを適用し、Asia/Tokyo の ID を filename と Frontmatter に設定する。
2. Study App の repository root で次を実行する。

   ```powershell
   npm run vault:prepare -- "C:\Users\m-maruyama\Development\Document organization"
   ```

   このコマンドは Vault の `study/**/*.md` と `wiki/**/*.md` を `content/notes/` へ厳密に同期し、Frontmatter、ID、重複、静的 route、Wiki Link、HTML 安全化を検証して `dist/` を生成する。0バイトのファイルは下書きとして警告し、削除しない。Vault から削除した同期済み記事は内容 hash を照合してミラーから除去し、`content/notes/` だけに存在する記事はエラーにする。
3. `git diff --check` と `git diff` で、同期記事、`generated/`、`dist/` の差分を確認する。
4. 変更を commit / push し、OpenAI Sites の既存プロジェクト `appgprj_6aba0a652f848191850dc665b7023bc0` へ `dist/` を反映する。

検証だけを行う場合は `npm run vault:check -- "<Vault path>"`、削除を反映せず追加・更新だけ同期する場合は `npm run vault:sync -- "<Vault path>"` を使う。通常の公開準備では正本と一致させる `vault:prepare` を使う。

公開済みの静的サイト上のファイル選択 UI から Vault を直接更新・再デプロイすることはできない。ブラウザーは任意のローカルフォルダへ常時アクセスできず、Sites への永続反映には認証された build/deploy 処理が必要なため、現段階の「アップロード」に相当する操作は上記ローカルコマンドとする。
