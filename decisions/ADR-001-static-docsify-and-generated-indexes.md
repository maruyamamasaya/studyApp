---
status: active
updated: 2026-08-28
---

# ADR-001: Docsify の静的サイトと生成索引を維持する

## Context

Git 履歴では 2026-07-27 の `Simplify Docsify index for Markdown notes` 以降、Docsify を中心に閲覧機能が追加されている。2026-07-31 の `Add persistent article learning progress` で記事 ID と localStorage が導入され、その後も `Sync notes` により Markdown と二つの JSON 索引が更新されている。現在のコードにはアプリケーションサーバー、DB、パッケージビルドがない。

当時の議論、代替案の比較、採用理由を説明する設計資料は見つからなかった。そのため、以下は履歴と現行実装から確認できる決定だけを記録し、動機は推測しない。

## Decision

- Markdown を `docs/` の静的資産として置き、Docsify がブラウザーで取得・描画する構成を現在の基準とする。
- `build_note_index.py` で `_note-index.json` と `_article-master.json` を生成し、Markdown の変更とともに Git 管理する。
- `_article-master.json` は既存パスの UUID を維持し、reader tools の localStorage キーを安定させる。
- ルートサイトと研修サイトは reader tools、Wiki link 処理、見出し処理、スタイル、全体索引を共有し、サイト固有差分は HTML の設定で与える。

## Consequences

- サーバーや DB なしで静的ファイルとして配信できる。
- Markdown の追加・移動・削除では生成スクリプトの再実行が必要になる。
- 記事のパス変更は新しい記事 ID になるため、既存のブラウザー学習記録との連続性が失われ得る。
- 実行時の Docsify CDN とブラウザー機能に依存する。
- サーバー側認証や端末間の状態同期はこの構成だけでは提供されない。

## Evidence

- Git commits: `9371cbe`, `21fd03a`, `2dc2448`。
- Current implementation: `docs/index.html`, `docs/training/index.html`, `build_note_index.py`, `docs/reader-tools.js`。

## Unknown

静的構成を選んだ当初の比較対象、正式なホスティング先、可用性・セキュリティ要件は確認できない。これらを将来変更する場合は要件を確認し、この ADR を supersede する。
