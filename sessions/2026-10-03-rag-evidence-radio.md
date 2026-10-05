# 根拠を確かめるRAGラジオ3本

- 依頼: アプリ名の英語案を相談し、追加で3記事を選んでラジオ形式の音声を制作。
- 名前: Learnleaf / Study Grove / Learn & Listenを候補として提示。名前の選択と表示名変更は未実施。
- 原本: Rerank（20261001-171545）、Metadata Filter（20261001-171546）、Hallucination（20261001-171550）。catalogと記事本文のhash一致を確認。
- 制作: ずんだもん質問役・四国めたん説明役、ノーマル、各24発言。ローカルVOICEVOXを2件まで同時実行。前回の速度/抑揚設定を維持。PCM音声に発言間0.16秒の無音を挿入して結合。
- 計測: 3本の音声生成・結合は96.4秒。調査/台本/コピーは含まない。生成済み発言を一時キャッシュへ保存。追加のLLM呼び出しなし。

- Rerank・根拠をもう一度見比べよう: trackID 106e2ab7-ff31-4be6-baa2-0b1b0c05aab8 / 音声 175.0秒 / 生成・結合 31.4秒
- Metadata Filter・資料の名札と鍵: trackID d868a4f9-217a-4b38-a9de-643d7202fba8 / 音声 174.1秒 / 生成・結合 31.4秒
- Hallucination・自信満々でも正しい？: trackID e3604b75-c902-4b6b-bb8c-165f0f58345d / 音声 177.1秒 / 生成・結合 33.5秒

- 保存: iCloud StudyAudioへ音声・話者名入り台本・track JSONを追加。rag-evidence.playlist.jsonで「ずんだもんとめたんのRAGラジオ・根拠を確かめる編」を作成。既存音声は維持。
- 検証: WAV形式/非無音/長さ、管理JSON参照、番組のtrackIDs、記事hash、コピー前後hash一致。索引再生成差分なし、diff check成功。
- 残課題: 聴感とiPhone同期・実再生は未確認。アプリの実装/ビルド変更なし。
