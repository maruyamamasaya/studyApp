# AI エージェント作業ガイド

このファイルは、このリポジトリで継続開発を始めるための入口である。公開する学習記事そのものではなく、リポジトリの保守手順を扱う。

## 作業開始時

1. この `AGENTS.md` を読む。
2. [`CURRENT.md`](CURRENT.md) で現在の状態、制約、次の候補を確認する。
3. [`ARCHITECTURE.md`](ARCHITECTURE.md) で変更箇所の責務とデータフローを確認する。
4. タスクに関係する [`decisions/`](decisions/) の記録だけを読む。
5. 関係するコード、テスト、Git 履歴を一次情報として調査する。

`docs/` には多数のコンテンツがある。全記事を無条件に読まず、タスクに必要な記事と索引だけを選ぶこと。

## 実装時の原則

- 推測だけで変更せず、既存実装と履歴を確認する。コードが現在の挙動を示しても、その理由が不明なら理由まで推測しない。
- 現在の静的 Docsify 構成と、ルートサイト・`docs/training/` サイト間の共有資産を意識する。
- 無関係な整形、記事改稿、生成物変更を混ぜない。
- セキュリティや権限を安易に弱めない。特に `docs/password-gate.js` はクライアント側の表示制御であり、本物のアクセス制御として扱わない。
- エラーを隠すだけの回避策を恒久対応にしない。原因、暫定性、残課題を記録する。
- Markdown の追加・改名・削除後は `python3 build_note_index.py` を実行し、`docs/_note-index.json` と `docs/_article-master.json` を同じ変更に含める。既存記事の ID は維持する。
- `docs/` は外部ノートから同期される運用がある。同期方法を変える場合は [`docs/md更新用コマンド.md`](docs/md更新用コマンド.md) と競合しないか確認する。

## 検証コマンド

依存パッケージのインストールやビルド工程は現在存在しない。変更範囲に応じて、実在する次のコマンドを使う。

```bash
node tests/password-gate.test.js
node tests/unique-heading-ids.test.js
python3 build_note_index.py
git diff --check
```

索引生成を検証目的で実行した場合、意図しない記事 ID や索引差分がないか `git diff` で必ず確認する。ブラウザー挙動を変えた場合は、可能ならローカル HTTP サーバーでルートサイトと研修サイトを確認する。

## Definition of Done

タスク終了前に原則として以下を行う。

1. 変更に必要なテストを実行する。
2. lint が存在すれば実行する（現在は専用設定なし）。
3. typecheck が存在すれば実行する（現在は専用設定なし）。
4. build が存在すれば実行する（現在の実質的な生成工程は `python3 build_note_index.py`）。
5. `git status`、`git diff`、`git diff --check` を確認する。
6. ドキュメント更新の要否を判定する。
7. 状態・制約・優先事項が変わった場合は `CURRENT.md` を更新する。
8. 現在の構成やデータフローが変わった場合は `ARCHITECTURE.md` を更新する。
9. 根拠を確認できる重要な設計判断があれば `decisions/` に ADR を追加する。
10. `sessions/YYYY-MM-DD-短い名前.md` に調査・実装・検証・残課題を簡潔に記録する。
11. 未解決事項を `CURRENT.md` または session に明示する。

存在しないコマンドやツールを形式のためだけに追加・実行しない。

## 記録の分担

- 現在どうなっているか: `CURRENT.md`
- 現在どう動いているか: `ARCHITECTURE.md`
- なぜその選択をしたか: `decisions/`
- 何をしたか: `sessions/`
- AI がどう作業するか: `AGENTS.md`

同じ内容を複製しない。CURRENT と ARCHITECTURE は現行情報に保ち、古い重要判断は削除せず ADR の supersede で残す。一時的な細部は ADR にしない。
