# ADR-009: Webと独立したアプリ向け記事配信一覧を生成する

status: accepted
updated: 2026-10-02

## 背景と判断

ユーザーには現在Macがなく、iOSのビルド・実機検証を後へ回し、Windowsで検証できる記事配信の仕様と生成処理を先に整える方針が承認された。ADR-008のHTTPS取得と機能独立を実装側で具体化する。

通常のVault同期でapp-articles.v1.jsonを生成する。既存のWeb用metadataは変更せず、一覧のSchema版、変更識別子、記事ID、相対path、表示metadata、本文hashを契約とする。生成時刻は含めず、同じ入力には同じ一覧を生成する。

Git checkoutがWindowsのCRLFを公開先でLFへ変える場合があるため、本文hashはFrontmatterを含む全MarkdownのCRLFをLFにそろえてSHA-256を計算する。本文自体は整形しない。同期manifestの原文hashと、アプリ向けの改行差を吸収するhashは目的を分ける。

HTTP検証CLIで一覧と全記事を取得して照合する。新JSONの公開確認、iOSの画面・保存・ビルドは後続作業とする。正式契約はAPP_ARTICLE_DELIVERY.mdに置く。
