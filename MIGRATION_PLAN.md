---
status: active
updated: 2026-09-29
---

# Study App 再構築計画

## 方針

既存 `maruyamamasaya/study` / `docs/` の343記事と学習状態は、新 Study App へ一括移行しない。旧サイトとファイルは参照用・rollback用として変更せず保持し、今後必要な記事を Obsidian Vault で新しく作り直す。

記事の唯一の正本は次のローカル Obsidian Vault とする。

```text
C:\Users\m-maruyama\Development\Document organization\study\**\*.md
C:\Users\m-maruyama\Development\Document organization\wiki\**\*.md
```

`content/notes/**/*.md` は正本ではなく、Git、build、OpenAI Sites で同じ入力を再現するための公開用ミラーである。手編集を禁止し、同期 script だけが更新する。`docs/`、旧 GitHub Pages、旧 localStorage は変更・削除しない。

## データフロー

```text
Obsidian Vault（唯一の正本）
  └─ vault:prepare
       ├─ Frontmatter / ID / path / duplicate 検証
       ├─ content/notes/ へ厳密同期
       ├─ generated/ の索引生成
       └─ Astro static build → dist/ → OpenAI Sites
```

同期方向は Vault → Study App の一方向とする。Vaultから削除した同期済み記事は、前回同期時のhashと一致する場合だけ `vault:prepare` がミラーから除去する。ミラーだけに追加された記事、同期後に直接変更された記事はエラーにし、自動採用・自動削除しない。

## 完了済み

- Astroの静的一覧、研修一覧、ID固定の個別記事route。
- DATA_MODEL準拠のFrontmatter、ID / filename、一意性、path検証。
- Wiki Linkのtitle / alias / ID filename / path / heading解決と曖昧リンク保護。
- 生HTML例の非実行化、task list、重複見出し。
- ObsidianのStudy / Wiki templateとExplorer Titles。
- Vault記事の厳密同期、OpenAI Sitesでの閲覧。
- `vault:check`、`vault:sync`、`vault:prepare`。
- 新ID単位の学習状態version 2。読了、学習時間、最終閲覧日時、`study`記事集計、JSONバックアップ／復元。

## 次の段階

### 1. 新規記事の作り直し

- 必要な知識だけをObsidianで新規作成する。
- 旧記事のID、作成時刻、学習状態を推測して転記しない。
- 旧記事を参考にした場合は、新記事本文または記録に出典となる旧pathを明示する。
- 同名記事や曖昧Wiki Linkは人が判断し、自動で結び付けない。

### 2. Reader機能

- title、tag、本文検索。
- navigationと目次の改善。
- mobile / desktop、code copy、attachment表示。
- `type: study` / `type: wiki` のfilterと集計。

### 3. 学習状態の拡張

- 実装済みのStudyProgressRepositoryとbackup version 2を維持する。
- checklistを新ID向けに実装する。
- 旧localStorageとbackup version 1は自動移行しない。必要ならread-only exportとして別途扱う。

### 4. 運用自動化

- Obsidian Vault自体のprivate Git / backup方針を決める。
- Sites sourceへのpushとdeployの自動化を検討する。
- `content/notes/`をGitから除外する場合は、clean checkoutがVaultまたは専用content repositoryから再現できる仕組みを先に用意する。

## 公開・rollback

- 新サイトはOpenAI Sitesの既存private projectを使う。
- `.openai/hosting.json`のproject IDと`dist/`公開設定を維持する。
- 旧Docsifyサイトは削除せず、必要な旧情報を確認する参照先として残す。
- 新サイトに問題がある場合は直前のSites versionへ戻す。旧データを新サイトから書き換えないため、旧サイト側の状態は破壊されない。

## Git運用

- Study App repositoryにはアプリ、同期script、検証、公開ミラー、生成物を記録する。
- Obsidian Vaultは記事の正本として別管理する。現時点ではGit repositoryではないため、backup / version管理は残課題とする。
- `content/notes/`を直接編集したcommitは受け入れない。
