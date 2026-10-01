# ADR-006: DocsifyとGit同期へ整理する

status: accepted
updated: 2026-10-01

## 判断

ユーザーが記事更新の単純化、日常のAI利用枠消費の排除、不要資源削除を希望し、Docsifyへ戻すことを承認した。Vaultが唯一の正本という判断は維持し、docsへMarkdownを同期して配信する。

- Astro buildとSites/Codex CLI公開を廃止する。
- GitHub Pages向けworkflowはdocsをそのまま配信する。
- サイト・repository・Git履歴の一般公開はユーザー承認済み。現在のプランでPagesを使うためrepositoryをpublicにする。
- 旧Astro学習状態は自動移行しない。

ADR-002のAstro採用、ADR-003のSites配信、ADR-004/005のcontent/notes配置をsupersedeする。Frontmatter検証、安定ID、Vault正本、hash付き一方向同期は維持する。
