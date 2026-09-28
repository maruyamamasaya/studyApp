---
status: accepted-for-implementation
updated: 2026-09-28
---

# Study App データモデル

## 原則

```text
Content data                 User learning state
Markdown + Frontmatter      local repository adapter
Git で共有・再利用           端末または将来の cloud に保存
```

学習状態を Frontmatter に書かない。path、title、filename は identity にしない。共通の identity は `frontmatter.id` とする。

## Markdown 配置

目標構成は `content/notes/**/*.md`。Obsidian vault は `content/` または `content/notes/` を開けるものとし、Web 実装固有ファイルは `app/`、生成物は `generated/` または build output に分離する。folder は整理と閲覧 scope に使えるが、identity には使わない。

新規 filename は `<id>.md` とする。

```text
20260928-142430.md
```

ID は Asia/Tokyo のローカル時刻を `YYYYMMDD-HHmmss` で表す。一度発行した ID は rename、title 変更、folder 移動でも変更しない。同一秒の重複は generator が未使用になるまで秒を進める。build は ID 重複、filename と ID の不一致を error にし、自動修正しない。

## Frontmatter schema

```yaml
---
id: 20260928-142430
title: ゼロトラストの基本
type: study
tags:
  - security
  - zero-trust
created: 2026-09-28 14:24:30
aliases:
  - Zero Trust
---
```

| field | 型 | 規則 |
| --- | --- | --- |
| `id` | string | 必須。`^\d{8}-\d{6}$`、全 note で一意、原則 filename stem と一致 |
| `title` | string / null | field は共通 schema に含める。空・空白・欠落は parser が null に正規化し、UI は `未設定` と表示 |
| `type` | string enum | 必須。初期値は `study` / `wiki`。未知 type は build error ではなく warning として拡張を許可する案を Phase 1 でテスト |
| `tags` | string[] | 必須、空配列可。trim、空要素除外、重複除去。表示文字列の case は維持 |
| `created` | local datetime string | 必須。`YYYY-MM-DD HH:mm:ss`、Asia/Tokyo として解釈 |
| `aliases` | string[] | optional。trim、空要素と title 重複を除外 |

`created` は「この knowledge record が作られた時刻」と定義する。legacy note は Git で確認できる最初の追加時刻を使い、確認できない場合は移行時刻を使って migration report に記録する。記事本文の執筆日を推測しない。

title は三つの値を分ける。

```text
rawTitle       = frontmatter の値。空なら null
displayTitle   = rawTitle ?? "未設定"
internalLabel  = rawTitle ?? aliases[0] ?? filename stem ?? id
```

内部 fallback を UI に漏らさない。

## 正規化 Article model

```ts
type ArticleType = 'study' | 'wiki' | string;

interface Article {
  id: string;
  path: string;
  filename: string;
  title: string | null;
  displayTitle: string;
  type: ArticleType;
  tags: string[];
  aliases: string[];
  created: string;
  legacyId?: string;
  legacyPath?: string;
}
```

`legacyId` と `legacyPath` は migration / generated metadata だけに存在し、Markdown Frontmatter へは書かない。

## 生成物

### article master version 2

```json
{
  "version": 2,
  "generatedAt": "2026-09-28T14:24:30+09:00",
  "articles": [
    {
      "id": "20260928-142430",
      "path": "notes/security/20260928-142430.md",
      "title": "ゼロトラストの基本",
      "type": "study",
      "tags": ["security", "zero-trust"],
      "aliases": ["Zero Trust"],
      "created": "2026-09-28 14:24:30",
      "legacyId": "existing-uuid"
    }
  ]
}
```

`displayTitle` は presentation rule なので生成物へ重複保存せず consumer が算出する。`legacyId` は移行期間のみ出力する。

### link index

一つの文字列から複数候補を保持する。

```ts
interface LinkCandidate {
  id: string;
  path: string;
  matchedBy: 'title' | 'alias' | 'filename' | 'path';
}

type LinkIndex = Record<string, LinkCandidate[]>;
```

解決順は explicit path、exact title、exact alias、filename stem。候補が複数残る場合は build warning と UI 上の曖昧 link にし、自動で一件を選ばない。標準 relative Markdown link はそのまま優先し、Wiki Link は compatibility syntax とする。

### search index

最低限 `id`、`title`、`tags`、検索用本文、path を生成する。UI 表示には本文 snippet を使う。`aliases`、`type`、`created` は最初から index field に含め、初期 UI で filter を公開しなくても schema を再変更せず利用できるようにする。

## 学習状態 version 2

```ts
interface StudyProgress {
  version: 2;
  completed: boolean;
  completedUpdatedAt: string | null;
  learningSeconds: number;
  lastViewedAt: string | null;
}

interface StudyProgressRepository {
  get(articleId: string): Promise<StudyProgress>;
  save(articleId: string, progress: StudyProgress): Promise<void>;
  list(): Promise<Record<string, StudyProgress>>;
}
```

validation rule:

- `learningSeconds` は有限の0以上の整数。
- 日時は有効な ISO 8601 または null。
- missing field は default で補えるが、型不正 record は隔離して報告する。
- `type: study` だけを既定の読了率分母とする。`wiki` は既定で対象外。

最初の adapter は localStorage。key は次とする。

```text
study:v2:progress:<frontmatter.id>
study:v2:checklist:<frontmatter.id>:<task-key>
study:v2:migration:legacy-v1
```

UI / domain は localStorage を直接呼ばず repository interface のみ使う。将来 Supabase 等へ adapter を追加しても Markdown schema は変えない。

## Checklist model

初期 `task-key` は、同一記事内の正規化 task text と同文言 occurrence から生成する。移行時に現行 key と同じ意味を再構成できる。article ID を含むため path 移動には耐えるが、文言変更には耐えない。

文言編集後も状態を厳密に保つ要件が生じた場合だけ、Markdown と Obsidian で無害な HTML comment に明示 task ID を追加する。初期移行で全 task に ID を大量付与しない。

## Backup version 2

localStorage の物理 key / string value を公開形式にしない。

```json
{
  "format": "study-notes-backup",
  "version": 2,
  "exportedAt": "2026-09-28T05:24:30.000Z",
  "records": {
    "progress": {
      "20260928-142430": {
        "version": 2,
        "completed": true,
        "completedUpdatedAt": "2026-09-28T05:20:00.000Z",
        "learningSeconds": 4320,
        "lastViewedAt": "2026-09-28T05:24:00.000Z"
      }
    },
    "checklists": {
      "20260928-142430": {
        "task-key": true
      }
    }
  }
}
```

version 1 は compatibility importer が受け取り、legacy UUID / path mapping を通して version 2 の in-memory model に変換してから保存する。未対応 record は件数と key を表示し、export 可能な quarantine に残す。

## Legacy mapping

移行 manifest は次の一対一対応を Git 管理する。

```json
{
  "version": 1,
  "entries": [
    {
      "legacyId": "uuid",
      "legacyPath": "記事：基礎編/example.md",
      "id": "20260928-142430",
      "path": "notes/study/20260928-142430.md"
    }
  ]
}
```

validation は legacy article master の343件が重複も欠落もなく対応すること、新 ID と新 path が一意であることを要求する。mapping は移行完了後も version 1 backup import のため保持する。

## Obsidian templates

Study:

```md
<%*
const id = tp.date.now("YYYYMMDD-HHmmss");
await tp.file.rename(id);
-%>
---
id: <% id %>
title:
type: study
tags: []
created: <% tp.date.now("YYYY-MM-DD HH:mm:ss") %>
---

# 概要
```

Wiki は `type: wiki` とし、本文 heading を強制しない。template に user state は含めない。
