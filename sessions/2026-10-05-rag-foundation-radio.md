# RAG全体像と取り込みの掛け合いラジオ

- 依頼: 未制作のRAG基盤記事をVOICEVOXの掛け合い音声にする。既存の7記事を照合し、今回は学習順の補完として3記事を制作。
- 原本: 配信catalogと記事本文のSHA-256一致を確認。全体構成は役割の地図、処理フローは架空のPC購入申請、文書取り込みは抽出品質と更新・削除を軸に構成。
- 台本/生成: 各24発言。ずんだもん質問役、四国めたん説明役、ノーマル。speedScale 1.08/1.04、intonationScale 1.15、発言間0.16秒、24kHz/mono/16bit PCM。VOICEVOX 0.25.1を起動し、ローカルAPI最大2件同時実行。英語略語は読みやすいカタカナ表記。
- RAG全体構成・二つの側と三つの役割: articleID 20261001-171534 / trackID b3ebc369-7c73-4424-a304-8be5824a9336 / 198.5秒。
- RAGの処理フロー・質問から回答まで: articleID 20261001-171535 / trackID ead82caa-68de-45e8-9238-c3b100b4c902 / 201.2秒。
- 文書取り込み・回答品質の土台を作ろう: articleID 20261001-171536 / trackID a6a65e19-5377-4187-bbba-eb7831904faf / 201.0秒。
- 音声生成・結合は合計110.8秒（調査・台本作成・保存を含まない）。一時制作物と発言cacheは/private/tmp/study-rag-foundation。
- 出力: iCloud Drive/StudyAudioへWAV・話者名入り台本・track JSONを追加。rag-foundation.playlist.jsonの「ずんだもんとめたんのRAGラジオ・全体像と取り込み編」で上記順、曲間3秒。
- 検証: WAV形式/長さ/非無音、記事hash、JSON参照、trackID重複なし、取り込み音声合計300MB未満、コピー前後hash一致。索引再生成差分なし、diff check成功。アプリコード変更なし。既存の未コミット変更は別作業として維持。
- 残課題: 聴感とiPhone同期・実再生は未確認。学習記事49件のうち掛け合い制作済み10件、残り39件。次の学習順候補はPDF解析（171537）、OCR（171538）、Vector Search（171541）、Keyword Search（171542）。恒常的な制作CLIは未追加。
