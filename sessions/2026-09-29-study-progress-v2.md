# 学習状態 version 2

## 調査

- 旧DocsifyのUUID単位progress、active時だけ動くtimer、読了時停止、backup mergeを確認した。
- 新データモデルではFrontmatter IDをidentityとし、旧localStorageを自動移行しない方針を確認した。

## 実装

- `StudyProgressRepository`のlocalStorage adapterを追加し、`study:v2:progress:<article-id>`へ読了、学習秒数、最終閲覧日時を保存する。
- 記事画面に読了ボタンと学習時間を追加した。画面がvisibleかつfocus中で未読了の場合だけ計測し、blur、非表示、pagehide、読了で停止する。
- サイドバーに`study`記事だけの読了数・合計学習時間を表示し、version 2 JSONの保存／復元を追加した。`wiki`記事の個別記録は行うが集計分母には含めない。
- 復元時は学習時間の大きい方、最新timestampの読了状態・最終閲覧日時を採用する。

## 検証

- domain testを17件実行し、記事ID別保存、不正値拒否、backup検証・merge、`study`限定集計を確認した。
- 生成HTML testを8件実行し、記事UI、ID、バックアップ導線を確認した。
- password gate testとunique heading ID testを実行し、いずれも成功した。
- Astro buildを実行した。起動中のpreviewが`.astro/content.d.ts`を一時的に保持して最初の実行が`EBUSY`になったが、再実行はコード変更なしで成功した。
- ブラウザーで学習時間の増加、読了時停止、再読込後の保持、別記事との分離、サイドバー集計、390px幅の横overflowなし、console errorなしを確認した。

## 残課題

- checklist version 2は未実装。
- localStorageは同一ブラウザー・同一端末内の保存であり、端末間同期は行わない。
- 旧backup version 1の自動移行は行わない。
