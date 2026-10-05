# 記事閲覧中の再生バー

- 依頼: 下のタブバーのすぐ上に再生バーを表示し、記事を読みながら音声を操作する。
- 調査: 現行資料・AudioMiniPlayer/TrackPlayer/各NavigationStackを確認。既存のミニプレイヤーは聴く/番組の画面内に限定されていた。既存未commit変更を維持。
- 実装: 5タブそれぞれのNavigationStack外側へbottom safeAreaInsetで配置。記事本文や番組詳細のpush後も表示を維持。再生進捗を追加。共有TrackPlayerによる再生/一時停止、詳細シートは既存処理を利用。
- 検証: iPhone 17e Simulator向けxcodebuild test成功。索引再生成の差分なし。git diff --check成功。専用lint/typecheck設定なし。
- 残課題: 実音声を使った配置・操作の目視確認、実機への今回の変更の導入は未実施。
