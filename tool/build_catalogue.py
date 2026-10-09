#!/usr/bin/env python3
"""Builds assets/audio/catalogue.json from the native iOS app's bundled catalogue (main.db).

    python3 tool/build_catalogue.py           # write the catalogue
    python3 tool/build_catalogue.py --check   # fail if the committed catalogue is stale (CI)

Album and track ids are kept exactly as in main.db, so anything the native app stored by id
still points at the same recording. The audio itself stays on the server:
https://scripts.12stepapp.com/tracks/{folder}/{file} (FLUTTER_ARCHITECTURE §0).
"""
from __future__ import annotations

import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "content-source" / "audio" / "main.db"
OUT = ROOT / "assets" / "audio" / "catalogue.json"
BASE_URL = "https://scripts.12stepapp.com/tracks/"

# The native app's album tile gradients (_Constants.swift colorGradientFrom/To), by list position.
GRADIENTS = [
    ("#0D324D", "#7F5A83"), ("#1E3B70", "#29539B"), ("#4CA2CD", "#67B26F"),
    ("#2657EB", "#DE6161"), ("#7C98B3", "#637081"), ("#556270", "#4ECDC4"),
    ("#7BC6CC", "#BE93C5"), ("#19547B", "#FFD89B"), ("#4CA1AF", "#2C3E50"),
    ("#CB3066", "#16BFFD"), ("#1FDDFF", "#FF4B1F"),
]

# D-005: no "AA" prefix in app titles. The recordings' own track titles are left alone.
SHORT_NAME_RENAMES = {"AA Big Book": "The Big Book"}


def size_bytes(label: str) -> int | None:
    m = re.fullmatch(r"\s*([\d.]+)\s*MB\s*", label or "")
    return round(float(m.group(1)) * 1_000_000) if m else None


def build() -> dict:
    db = sqlite3.connect(DB)
    db.row_factory = sqlite3.Row
    albums = []
    # The native app lists albums in id order (THE_QUERY ... GROUP BY albums.id).
    for position, a in enumerate(db.execute("SELECT * FROM albums ORDER BY id")):
        tracks = []
        for number, t in enumerate(
            db.execute("SELECT * FROM tracks WHERE album_id = ? ORDER BY id", (a["id"],)), start=1
        ):
            track = {
                "id": t["id"],
                "number": number,
                "title": t["title"],
                "file": t["file_name"],
                "seconds": t["file_length"],
                "sizeLabel": t["file_size"],
            }
            approx = size_bytes(t["file_size"])
            if approx:
                track["approxBytes"] = approx
            tracks.append(track)
        if len(tracks) != a["total_count"]:
            raise SystemExit(f"album {a['id']}: {len(tracks)} tracks, main.db says {a['total_count']}")
        start, end = GRADIENTS[position]
        albums.append({
            "id": a["id"],
            "title": a["title"],
            "shortName": SHORT_NAME_RENAMES.get(a["shortname"], a["shortname"]),
            "folder": a["variable"],
            "hasTranscripts": bool(a["html"]),
            "seconds": sum(t["seconds"] for t in tracks),
            "gradient": [start, end],
            "tracks": tracks,
        })
    return {"version": 1, "baseUrl": BASE_URL, "albums": albums}


def render(catalogue: dict) -> str:
    return json.dumps(catalogue, ensure_ascii=False, indent=1) + "\n"


def main() -> int:
    text = render(build())
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("assets/audio/catalogue.json is stale: run python3 tool/build_catalogue.py")
            return 1
        print("audio catalogue up to date")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    data = json.loads(text)
    print(f"{len(data['albums'])} albums, {sum(len(a['tracks']) for a in data['albums'])} tracks"
          f" -> {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
