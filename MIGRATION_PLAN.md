---
status: accepted-for-implementation
updated: 2026-09-28
---

# Study Scratch & Build 移行計画

## ゴールと境界

新しい開発先は `maruyamamasaya/studyApp`。既存 `maruyamamasaya/study` とその公開サイトは legacy として維持し、新サイトの検証が終わるまで上書きしない。

今回の移行は次を同時に成立させる。

- Markdown + Frontmatter を Git 管理された正本にする。
- Obsidian、Study Web、my-wiki、SecondBrain、将来の RAG が同じ content を利用できる。
- filename / title / path から独立した永続 ID を導入する。
- 既存 UUID ベースの progress、path ベースの checklist、version 1 backup を失わない。
- 静的 hosting を維持し、user state は content から分離する。

この文書は実装順、移行 gate、rollback を定める。schema の詳細は `DATA_MODEL.md`、現行仕様は `CURRENT_FEATURES.md` を正とする。

## 技術選定

### 比較

| 候補 | Markdown / Frontmatter | 静的配信 | 学習 UI | 主な懸念 | 判定 |
| --- | --- | --- | --- | --- | --- |
| Docsify 継続 | 実行時 parser。build validation は自作 | build 不要 | 現行資産を再利用しやすい | schema、broken link、full-text search を公開前に検出しにくい。CDN/runtime 依存が残る | legacy のみ |
| Vite + React | parser、route、index を自由設計 | 静的出力を Sites へ配信可能 | SPA に最適 | content pipeline と静的 article route をほぼ自作。JS なしでは本文が出にくい | 次点 |
| Next.js static export | route ごとの HTML を生成可能 | `output: 'export'` | React で実装可 | static export で server feature が使えず、今回には framework complexity が大きい | 不採用 |
| Astro static | content collection、schema validation、静的 route | 既定が静的、Sites へ静的出力を配信可能 | 必要部分だけ client script / island | 新 build toolchain と migration 作業が必要 | 採用 |

採用案は Astro + TypeScript の静的生成である。記事本文、metadata、内部 link は build 時に処理し、学習 controls、検索 dialog、timer、backup は小さな client-side TypeScript module とする。初期実装では UI framework を必須にせず、複雑性が実証された場合だけ React 等の island を追加する。

この選択の根拠:

- Astro content collections は local Markdown の loader と schema validation を持ち、build-time collection から静的 route を生成できる。
- 静的 output を OpenAI Sites へ配信できる。
- content 本文を静的 HTML にしつつ、localStorage に依存する部分だけを client で動かせる。
- app 固有 schema を Markdown に混ぜず、generated index を my-wiki 等へ公開できる。

公式資料:

- [Astro Content Collections](https://docs.astro.build/en/guides/content-collections/)
- [Astro static output](https://docs.astro.build/en/guides/configuring-astro/#output)
- [Vite static deployment](https://vite.dev/guide/static-deploy)
- [Next.js static exports](https://nextjs.org/docs/app/guides/static-exports)
- [Docsify](https://docsify.js.org/)

## 目標構成

```text
content/
  notes/                 # 正本 Markdown。Obsidian / 外部 consumer と共有
  templates/             # Templater templates
app/
  src/content.config.ts  # schema と content loader
  src/pages/             # home、article、training 等の静的 route
  src/domain/            # Article / Progress / Backup の純粋 domain
  src/repositories/      # localStorage adapter。将来 cloud adapter
  src/client/            # timer、search、navigation、dialogs
scripts/
  build-content-index.*  # article / link / search index
  migrate-legacy.*       # manifest 作成・検証
migration/
  legacy-article-map.json
  reports/
generated/               # 再生成可能な JSON
legacy-fixtures/          # master / backup の最小テスト fixture
```

実際の directory 作成は Phase 1 の vertical slice で確定する。既存 `docs/` は新 site が受入基準を満たすまで削除・置換しない。

## Phase 0: Inventory と設計

成果物:

- `CURRENT_FEATURES.md`
- `DATA_MODEL.md`
- `MIGRATION_PLAN.md`
- architecture 選定 ADR

完了 gate:

- legacy UUID 343件が一意であることを確認。
- Frontmatter 0件、Wiki Link 361件、同名 stem 4組、task 769件を移行対象として記録。
- version 1 backup と localStorage key の仕様を固定。
- new remote と legacy remote を分離。

## Phase 1: Markdown domain vertical slice

大量 rename の前に、代表 note 5–10件だけをコピーして parser と route を作る。対象には root home、training、同名 title、Wiki Link alias / heading、task list、重複 heading を含める。

実装:

1. Frontmatter schema と normalizer。
2. `displayTitle = 未設定` と internal fallback の分離。
3. ID / filename / path の invariant validator。
4. Study / Wiki templates。
5. Markdown sanitizer policy。教材中の HTML / XSS 例を executable HTML と誤認しないことを確認。

test:

- valid / missing / blank title。
- invalid / duplicate ID。
- tags / aliases normalize。
- Windows / POSIX path normalize。
- code fence、HTML sample、task list、重複 heading。

exit gate: sample collection が build され、Obsidian と生成 HTML の両方で内容を確認できる。

Phase 1 完了後の少数記事運用として、外部 Obsidian Vault の `study/` / `wiki/` から `content/notes/` への検証付き一方向同期を導入する。代表記事7件を Vault に初期配置し、Vault 既存・新規記事を含む12件で同期・静的生成を確認する。これは legacy 343記事の一括移行、ID 推定、学習状態移行を開始するものではない。

## Phase 2: ID inventory と index generator

まだ全 Markdown を rename しない状態で migration manifest を先に生成する。

1. 現行 `_article-master.json` を read-only baseline として固定。
2. 各 legacy path に新 ID を一度だけ割り当てる。
3. Git 上の earliest reliable add timestamp を `created` 候補にし、重複 ID は秒を進める。
4. timestamp を確認できない note は migration timestamp を使い、report に明示。
5. legacy UUID 343件すべてに一意な new ID があることを validator で確認。
6. article master v2、link index、search index を再生成可能にする。

path 比較では Unicode NFC / NFD の差を検出する。正規化後の一致は rename とみなせる候補として報告するが、複数候補を自動統合しない。現行 master の raw path と UUID は失わない。

生成を二回実行して manifest / JSON が同一になることをテストする。既存 ID を再発行する generator は禁止する。

exit gate:

- mapping 件数 = legacy master 件数 = migrated note 件数。
- duplicate / missing legacy UUID = 0。
- duplicate new ID / path = 0。
- Unicode normalization collision = 0。正規化差だけの path は review 済み mapping を持つ。
- unresolved / ambiguous Wiki Link report を出力し、同名4組を人が解決。

## Phase 3: Reader MVP

新 URL で並行公開する。

最低機能:

- static article route と direct URL。
- Frontmatter title / tags / type 表示。
- title、tags、本文検索。
- navigation、目次、standard Markdown link、Wiki Link compatibility。
- mobile / desktop layout、code copy、重複 heading anchor。
- `type: study` と `type: wiki` の表示・集計境界。

root site / training site を directory 偶然ではなく、metadata または明示 collection rule で構成する。training 公開範囲は legacy と同等であることを fixture で確認する。

exit gate: representative browsers で direct load、refresh、back / forward、Sites のルート URL、日本語 content、mobile layout を確認。

## Phase 4: Learning state adapter

`StudyProgressRepository` と localStorage adapter を実装する。UI は adapter を直接知らない。

順序:

1. read / write / validation。
2. completed と timestamp。
3. focus / visibility aware timer と flush。
4. manual time editor。
5. `type: study` の読了率 / 合計時間。
6. checklist repository。

fake clock と in-memory repository で timer をテストし、DOM event に依存する部分を最小化する。

exit gate: refresh、route 遷移、blur、hidden、pagehide、読了切替で重複・欠落なく秒数を記録する。

## Phase 5: Legacy state migration

### runtime migration

初回起動時に次を行う。

1. migration marker と mapping version を読む。
2. `study-notes:article:<legacy UUID>` を列挙。
3. manifest で new ID を解決し、version 2 progress に validate / normalize。
4. destination がない場合は copy。ある場合は backup merge と同じ規則で merge。
5. checklist key は右端から occurrence と item text を解析し、残りを legacy path として mapping。
6. mapped、merged、unmapped、invalid の件数を migration report として UI に表示・download 可能にする。
7. 全処理成功後に marker を保存。

旧 key は Phase B では削除しない。再実行時も学習時間は max、日時は latest を使うため重複しない。marker が壊れても同じ結果になる冪等性テストを持つ。

### backup v1 import

version 1 backup は localStorage へ直接書き戻さず、parser → legacy mapping → version 2 domain → repository の順に通す。mapping 不能 record は破棄せず quarantine と report に残す。

exit gate:

- UUID 付き fixture の全 progress field が一致。
- checklist fixture が article ID 配下へ移る。
- import / runtime migration の二回実行で結果が変わらない。
- invalid / unknown data が silent loss しない。

## Phase 6: Backup version 2

- structured version 2 export。
- overwrite / merge の両モード。
- version 1 / version 2 import。
- merge rule は current / imported の順序を逆にしても同一になるよう test。
- export → clear → import の round trip test。
- 将来 field は parser の version migration を経由し、localStorage key へ依存しない。

exit gate: 実ユーザーが取得した匿名化済み backup で staging restore を確認する。実 backup を repository に commit しない。

## Phase 7: 全 content 移行と polish

1. manifest を用いて Frontmatter 追加と ID filename への rename を機械的に実施。
2. rename は一つの専用 commit にまとめ、旧 path → new ID 対応を review 可能にする。
3. standard relative link へ安全に変換できる Wiki Link だけ変換。曖昧 link は手動解決。
4. Obsidian vault、attachments、template、search、theme、responsive UI を確認。
5. generated file の再現性と CI check を追加。

大量 content 変更と app 実装を同じ commit に混ぜない。

## Cutover と rollback

cutover 条件:

- 全343記事の mapping が完備。
- legacy backup v1 の restore が成功。
- progress / checklist の migration report に未解決0件、または承認済み例外だけ。
- root / training の重要 route と検索、内部 link、mobile を確認。
- legacy URL と新 URL の content sampling が一致。
- backup v2 を取得できる。

cutover 手順:

1. legacy site を更新停止し、最終 master / generated index の commit を記録。
2. 新 site を preview URL で最終確認。
3. 利用者へ先に version 1 backup 取得を案内。
4. 公開 URL を新 site へ切替。
5. rollback window 中は legacy site と旧 localStorage key を保持。

rollback は公開先を legacy に戻すだけで成立させる。新 site は旧 key を削除しないため、legacy 側の状態を破壊しない。

## Git 運用

- `origin`: `https://github.com/maruyamamasaya/studyApp.git`
- `legacy`: `https://github.com/maruyamamasaya/study.git`
- `main` は現在 upstream 未設定。最初に公開する baseline を確認後、`git push -u origin main` を明示実行する。
- legacy remote へは通常 push しない。
- new repository の最初の tag として legacy baseline commit を残し、Scratch & Build の比較基点にする。

## 既知の未決事項

- 新 site の最終公開 URL / custom domain と公開範囲。
- root content の本物のアクセス制御要否。現行 password gate は認証ではない。
- 外部 Obsidian vault の正本 location と、新 repository への同期方向。
- my-wiki / SecondBrain が要求する index schema と取り込み方式。
- anonymized real backup を使う受入テスト手順。

これらは Phase 1 の parser / sample 実装を止めないが、全 content 移行または cutover 前に解決する。
