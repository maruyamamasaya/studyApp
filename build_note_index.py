from __future__ import annotations

import json
import uuid
from collections import defaultdict
from pathlib import Path

DOCS_DIR = Path("docs")
OUTPUT_FILE = DOCS_DIR / "_note-index.json"
ARTICLE_MASTER_FILE = DOCS_DIR / "_article-master.json"
HOMEPAGE_FILE = "📚 Study Notes Hub.md"

index: dict[str, list[str]] = defaultdict(list)

try:
    current_master = json.loads(ARTICLE_MASTER_FILE.read_text(encoding="utf-8"))
except (FileNotFoundError, json.JSONDecodeError):
    current_master = {"articles": []}

article_ids = {
    article["path"]: article["id"]
    for article in current_master.get("articles", [])
    if isinstance(article, dict) and article.get("path") and article.get("id")
}
articles: list[dict[str, str]] = []

for markdown_file in DOCS_DIR.rglob("*.md"):
    relative_path = markdown_file.relative_to(DOCS_DIR)
    article_path = relative_path.as_posix()

    articles.append({
        "id": article_ids.get(article_path, str(uuid.uuid4())),
        "path": article_path,
        "title": markdown_file.stem,
    })

    # DocsifyのトップページはWikiリンクの解決対象から除外
    if relative_path.as_posix() == HOMEPAGE_FILE:
        continue

    path_without_extension = relative_path.with_suffix("").as_posix()
    note_name = markdown_file.stem

    index[note_name].append(path_without_extension)

sorted_index = {
    note_name: sorted(paths)
    for note_name, paths in sorted(index.items())
}

OUTPUT_FILE.write_text(
    json.dumps(sorted_index, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

ARTICLE_MASTER_FILE.write_text(
    json.dumps(
        {"version": 1, "articles": sorted(articles, key=lambda article: article["path"])},
        ensure_ascii=False,
        indent=2,
    ) + "\n",
    encoding="utf-8",
)

print(f"作成完了: {OUTPUT_FILE}")
print(f"ノート名: {len(sorted_index)}件")
print(f"記事マスター: {len(articles)}件")
print(
    "Markdownファイル: "
    f"{sum(len(paths) for paths in sorted_index.values())}件"
)
