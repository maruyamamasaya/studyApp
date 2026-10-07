# ローカル変更と取得済み最新mainの統合

- ユーザーの許可により、main cbde2b5から取得済みorigin/main a8d523aまで8コミットをfast-forward。再fetch・pushは行わない。
- 元の追跡済み変更と未追跡25ファイルをstashへ保存後、最新側へ再適用。復旧用stashは `StudyApp pre-integration 2026-10-06 local preservation` として保持。
- 競合3ファイル: APP_ARTICLE_DELIVERY.mdは任意type・未指定の空文字列化・未分類表示を統一。CURRENT.mdは双方の状態記録を保持。ios/Tests/StudyAppTests.swiftは最新側の混在type/非文字列拒否とローカル側の拡張type/不正path拒否を両方保持。
- 自動統合されたARCHITECTURE.mdおよび配信仕様・状態記録の旧必須type説明を最新同期仕様へ修正。
- 最新側の公開記事・匿名化・取込記録JSON・manifestはHEADから差分なし。未追跡25ファイルは保存時とバイト一致。Learnleafの番組編集・テーマ・検索・オフライン・記録統合を保持。
- 検証: Node22でnpm test 24件成功。python3 build_note_index.py成功、両索引JSON差分0。iOS XCTest 51件成功。git diff --check成功、未解消indexと競合マーカーなし。
- iOS: 既存Simulator 757967D4-AED3-41C8-8910-D6E1FDE398E6、並列無効・同時端末1。XCTestDevices前後18/18、新規複製0、削除0、テストプロセス残存0。ログ・前後端末JSON・時刻・プロセス記録: /tmp/studyapp-integration-20261006/。xcodegen再生成後、既存依存cacheを使い /tmp/learnleaf-roadmap にbuild/test。
- ローカル変更は元と同じ未コミット・未ステージとして残す。実機導入・公開は今回行わない。実機での自由type記事表示と音声操作等は既存記録どおり未確認。
