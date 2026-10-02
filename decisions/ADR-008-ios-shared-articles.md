# ADR-008: iOS版は共通記事をHTTPSで取得し独立した学習機能を持つ

status: accepted
updated: 2026-10-02
scope: 構想段階。実装は未着手。

## 判断と根拠

ユーザーは個人用iOS版を主な学習環境とし、Web側とiOS側の機能・記録は独立、記事は共通という方針を示した。サイト全体を包む方式から、管理する記事データを取得してアプリで表示する方式へ方針を変更し、HTTPS取得の説明を受けた上で構想文書の作成を依頼した。

Obsidianを正本とし、現行のGitHub Pagesへ配信した一覧JSONとMarkdownをHTTPSで取得する。iOSの学習記録は端末内で独立管理し、Web記録との同期・移行とオフライン閲覧は初期版の必須要件にしない。Gitのclone/pullやDocsify画面・localStorageへの依存を設けない。

記事の取得方式と記事IDは共有するが、描画方式、永続ストレージ、配信JSONの正式Schemaは実装前に確定する。具体的な範囲と手順は[IOS_APP_CONCEPT.md](../IOS_APP_CONCEPT.md)を参照する。現行Webのアーキテクチャは変更しない。
