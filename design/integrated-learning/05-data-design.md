# 5. データ管理設計書
状態: schema案。現行のarticleID/Frontmatterを変更しない。

## 正本と生成物

Vault/wikiのMarkdownは現行どおり記事正本。拡張案はVault/resources/<UUID>/meta.jsonとoriginal、deck.json、relations.json。公開生成物はdocs/assets/resources/<UUID>/<sha256>/配下とresources.v1.json、relations.v1.json。資料metadataは記事索引に偽の記事として追加しない。ここに示すresourcesフォルダは現行同期対象外で、将来専用検証が必要。

公開原本はpublishOriginal=trueの明示指定時だけ生成先へ含める。publish=falseが既定。公開用派生だけでも内容が公開されるので別のpublish承認が必要。private原本は公開Git repositoryへ置かない。端末importはIndexedDB/iOS Application Supportの別storeとし、公開metadataに混ぜない。

## リソース索引案

```json
{
  "schemaVersion": 1,
  "revision": "<catalog-sha256>",
  "articleCatalogRevision": "<article-catalog-revision>",
  "resources": [{
    "id": "<uuid>",
    "kind": "diagram",
    "title": "処理フロー",
    "category": "architecture",
    "tags": ["RAG"],
    "description": "入力から検索と生成までの流れ",
    "created": "2026-10-08T00:00:00Z",
    "updated": "2026-10-08T00:00:00Z",
    "version": 1,
    "files": [{
      "role": "safe-svg",
      "path": "assets/resources/<uuid>/<hash>/diagram.svg",
      "mime": "image/svg+xml",
      "bytes": 1024,
      "sha256": "<hash>"
    }]
  }]
}
```

例のUUID/hashは説明用。kindはdiagram/document/presentation、roleはoriginal/safe-svg/preview-pdf/thumbnail/text/png等を定義する案。original未公開なら索引にpathやprivate hashを入れない。画像はwidth/height、PDFはpageCount、抽出textはpage/slide位置情報、SVGはviewBox/安全化profileをoptional metadataに持つ。分類を記事typeと混同しない。

SHA-256はリソースではbyte列をそのまま計算し、記事のCRLF正規化と分ける。原本hash・派生hash・converter/version/profile/inputHashを私的制作manifestへ保存する。公開索引revisionはID順・定義済みフィールド順のJSONから決定的に生成し、生成時刻で毎回変えない。

## 相互参照のschema案

relationはid(UUID)、from{kind,id,elementID?}、to{kind,id,sectionID?}、purposeを持つ。参照IDは強制検証する。図解要素には原本が持つstable elementIDか制作側metadataを付け、表示DOMの一時IDとは対応表で分ける。article sectionには将来stable anchor metadataが必要で、現在の見出しslugを永続IDと保証しない。

本文埋め込みは普通の相対画像参照を維持し、既存パス参照をresourceIDへ索引解決する。移動時はID維持・path変更・参照スキャンで修正候補を提示する。SVGの外部articleリンクを直接実行せず、metadataの関係をviewer側が解決する。

## スライド保存案

deck.jsonはschemaVersion、id、title、sourceArticleIDs、sourceHashes、theme、layout、slidesを持つ。slideはid、source{articleID,sectionID?,sourceHash}、contentSnapshot、assetIDs、notes、manualOverride、order。記事更新時はsourceHash差分からstaleを検知し、新草稿と保存内容の比較を提示する。削除されたsectionや分割/結合したslideは自動で復元しない。本人承認後のみ新snapshotへ移行する。

## 更新・重複・削除

同byte hashは重複候補として示すがタイトル/関係が違えば論理IDを統合しない。派生cacheだけ内容hashで共有する。原本の更新はIDを維持しversion/hashを更新、派生再生成の成功後にmanifest確定。途中失敗で既存公開版を失わない。

削除前に逆参照一覧を示し、未解決はtombstone/警告で保持。未参照派生の清掃は保持期間経過後に限定。Gitは公開metadataと許可された公開派生を管理し、大容量originalを無条件commitしない。Git LFSを導入してもPages配信が自動成立するとは扱わず、上限と配信検証を別途行う。

## 個人記録の互換性

StudyBackup v1の既存記事配列とUUID sessionを維持。図解保存/slide位置/注釈はresource-state.v1として別ファイルから開始し、後でbackup envelopeへ明示統合する案。Web記録/iOS記録の自動統合は追加しない。二重ID、path traversal、hash、dangling refs、版不一致は公開前検証で拒否する。
