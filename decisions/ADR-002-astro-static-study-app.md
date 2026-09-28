---
status: accepted
updated: 2026-09-28
---

# ADR-002: 新 Study App は Astro の静的生成と分離した学習状態 adapter を採用する

この ADR は新 `studyApp` の実装判断である。現行サイトでは ADR-001 が引き続き active であり、cutover 完了時に supersede 関係を更新する。

## Context

現行 Study は Docsify が実行時に Markdown を描画し、filename stem と path を title / link / identity の一部として使う。再構築では Frontmatter schema、永続 ID、build-time link validation、本文検索、GitHub Pages、Obsidian / 外部 consumer との content 共有、および既存 localStorage の安全な移行が必要である。

候補として Docsify 継続、Vite + React、Next.js static export、Astro static を比較した。現行コードの再利用量だけでなく、Markdown 正本の検証、静的 route、client-side 学習 UI、build complexity を評価した。

## Decision

- 新 Study App は Astro + TypeScript の static output を採用する。
- Markdown は build-time content collection として読み、Frontmatter を schema validation する。
- article HTML と metadata は静的生成する。
- progress、timer、checklist、backup、検索 UI は client-side TypeScript とし、必要性が確認されるまで UI framework を必須にしない。
- user state は repository interface の背後に置き、最初の adapter を localStorage とする。
- existing Docsify site は cutover まで legacy として別 repository / URL で維持する。
- GitHub Pages を初期 hosting 候補とするが、平文 password gate を認証として移植しない。

## Consequences

- invalid metadata、duplicate ID、broken / ambiguous link を公開前に検出できる。
- article content は JavaScript 実行前でも静的 HTML として配信できる。
- npm dependency、lockfile、build、CI が新たに必要になる。
- Astro の directory / base path 規約を new GitHub Pages URL に合わせる必要がある。
- legacy reader tools を直接継ぎ足さず、domain / repository / UI に分割して実装し直す。
- React 等が必要になっても island として局所導入できるが、初期選定には含めない。

## Alternatives

### Docsify 継続

移行量は少ないが、build-time schema と静的 route を得にくく、Scratch & Build の主要目的を満たしにくい。

### Vite + React

学習 UI には適するが、Markdown collection、static article route、metadata validation の多くを独自実装する必要がある。Astro の client-side 部分でも Vite ecosystem を利用できるため、全面 SPA は選ばない。

### Next.js static export

静的 HTML は生成できるが、server feature が使えない構成に対して framework surface が大きい。今回の content-first site では Astro の collection model が直接的である。

## Evidence

- [Astro Content Collections](https://docs.astro.build/en/guides/content-collections/)
- [Astro GitHub Pages deployment](https://docs.astro.build/en/guides/deploy/github/)
- [Vite static deployment](https://vite.dev/guide/static-deploy)
- [Next.js static exports](https://nextjs.org/docs/app/guides/static-exports)
- 現行調査: `CURRENT_FEATURES.md`
- schema / migration contract: `DATA_MODEL.md`、`MIGRATION_PLAN.md`
