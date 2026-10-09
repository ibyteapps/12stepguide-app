#!/usr/bin/env python3
"""Builds assets/content_index.json from the front matter of the shipped Markdown documents.

    python3 tool/build_content_index.py           # write the index
    python3 tool/build_content_index.py --check   # fail if the committed index is stale (CI)

The app's lists read this index and never open a document to show a title (FLUTTER_ARCHITECTURE
§8). Only the folders the app bundles are indexed; content/archive/ is not.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
OUT = ROOT / "assets" / "content_index.json"

# Folder -> collection id, in the order the app presents them.
SHIPPED = {
    "steps": "steps",
    "traditions": "traditions",
    "readings": "readings",
    "prayers": "prayers",
    "sobriety-tips": "sobriety-tips",
    "big-book": "big-book",
    "stories-1st-edition": "stories-1st-edition",
    "stories-2nd-edition": "stories-2nd-edition",
    "transcripts/joe-and-charlie": "transcripts-joe-and-charlie",
    "transcripts/big-book": "transcripts-big-book",
}

PAGE = re.compile(r"<!-- page (\d+) -->")
HEADING = re.compile(r"^(#{1,2}) (.+)$", re.M)


def front_matter(text: str) -> tuple[dict, str]:
    if not text.startswith("---\n"):
        raise ValueError("no front matter")
    end = text.index("\n---\n", 4)
    block, body = text[4:end], text[end + 5:]
    data: dict = {}
    key = None
    for line in block.splitlines():
        if line.startswith("  - "):
            data.setdefault(key, []).append(json.loads(line[4:]))
            continue
        key, _, value = line.partition(":")
        key, value = key.strip(), value.strip()
        if value == "":
            data[key] = []
        elif value.startswith('"'):
            data[key] = json.loads(value)
        else:
            data[key] = int(value)
    return data, body


def build() -> dict:
    documents = []
    for folder, collection in SHIPPED.items():
        files = sorted((CONTENT / folder).glob("*.md"))
        if not files:
            raise SystemExit(f"no documents in content/{folder}")
        for path in files:
            meta, body = front_matter(path.read_text(encoding="utf-8"))
            if meta.get("collection") != collection:
                raise SystemExit(f"{path}: collection {meta.get('collection')!r} != {collection!r}")
            pages = [int(p) for p in PAGE.findall(body)]
            entry = {
                "id": meta["id"],
                "collection": collection,
                "order": meta["order"],
                "title": meta["title"],
                "path": str(path.relative_to(ROOT)),
            }
            for optional in ("subtitle", "pages", "aliases", "album_id", "track_id", "audio_file"):
                if meta.get(optional) not in (None, [], ""):
                    entry[optional] = meta[optional]
            if pages:
                entry["firstPage"] = pages[0]
                entry["lastPage"] = pages[-1]
            entry["words"] = len(re.sub(r"<!--.*?-->|[#*_>\\|`-]", " ", body).split())
            documents.append(entry)
    ids = [d["id"] for d in documents]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate document ids")
    return {"version": 1, "collections": list(SHIPPED.values()), "documents": documents}


def render(index: dict) -> str:
    return json.dumps(index, ensure_ascii=False, indent=1) + "\n"


def main() -> int:
    text = render(build())
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("assets/content_index.json is stale: run python3 tool/build_content_index.py")
            return 1
        print("content index up to date")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    count = text.count('"id"')
    print(f"{count} documents indexed -> {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
