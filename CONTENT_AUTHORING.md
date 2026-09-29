# Markdown 記事の追加と公開

## 配置場所とファイル名

新しい記事の正本は `content/notes/**/*.md` に置く。旧 Docsify 用の `docs/` には置かない。

通常の記事:

```text
content/notes/study/20260929-142430.md
```

研修一覧にも表示する記事:

```text
content/notes/training/20260929-142430.md
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
aliases:
  - Zero Trust
---

# 概要
```

- `title` は空欄でもよく、その場合の画面表示は `未設定` になる。
- `type` の初期値は `study` または `wiki`。未知の値は Phase 1 では warning として扱う。
- `tags` は必須の配列で、空なら `[]` とする。前後空白、空要素、重複は生成時に除去される。
- `aliases` は任意の配列。前後空白、空要素、重複、title と同じ値は除去される。
- `created` は Asia/Tokyo のローカル時刻。YAML parser に日時型へ変換されないよう引用符で囲む。

## 追加から公開まで

1. 記事を `content/notes/study/` または `content/notes/training/` に追加する。
2. Phase 1 の間は `migration/phase1-samples.json` に同じ ID と path を追加する。新規記事は `legacyId` / `legacyPath` を `null`、`copyMode` を `new` とする。
3. `npm run check` を実行する。Frontmatter、ID、静的 route、Wiki Link、HTML 安全化まで検証される。
4. `git diff --check` と生成された `generated/` / `dist/` の差分を確認する。
5. OpenAI Sites の既存プロジェクトへ Site workflow で source と `dist/` を保存・反映する。

Phase 1 の build は意図しない全件移行を防ぐため、記事数を5〜10件に制限している。この上限を外すのは Phase 2 の ID inventory と migration manifest 検証後とする。
