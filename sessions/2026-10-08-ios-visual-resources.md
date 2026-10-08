# iOS図解・資料・プレゼン実装

- 依頼: 設計と照合してiOSの実装フェーズ1〜10を進める。ユーザー指定により実際のテスト・実機確認は別途。添付依頼に従いcommit/pushする。
- 変更: UUID/hash原本ストア、SVG許可リスト、Office ZIP検証、PDFKit/Quick Look、PPTX+登録PDF、図解一覧・記事関連・検索、構造分割スライド・編集・ノート・更新比較、SVG/PNG/PDF/ZIP出力。アプリにZIPFoundationを追加しライセンス同梱。
- 設計差分: 公開resources catalogではなくiOS個人資料ストア。ネイティブ表示を再利用し変換サーバーは追加しない。詳細はADR-018とios/VISUAL_RESOURCES.md。
- 確認: コードと依存APIの目視照合、git diff --check、索引再生成と差分確認。XcodeGen/SPM解決/Swiftコンパイル/テスト/Simulator/実機の実行はしていない。WindowsにSwift/Xcodeなし。
- テスト追加: 能動SVG・外部参照・要素リンク、Office外部relationship/パス、取込・再起動・重複・原本更新・hash不一致・索引破損、コードフェンスを保持するスライド分割。
- 残課題: Macビルドと既存/追加テスト、実機受入・アクセシビリティ・メモリ計測。資料全体のバックアップ/端末間同期、Office自動変換、AIは未対応。既存Vault同期上書き保護の課題には変更を加えない。
