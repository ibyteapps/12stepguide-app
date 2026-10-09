#!/usr/bin/env python3
"""Album artwork for the lock screen and media notification (assets/images/albums/<id>.png).

    python3 tool/build_album_art.py

Each tile is the album's legacy gradient (assets/audio/catalogue.json) with its short name on a
45 % scrim, the same look the app draws in Flutter for album tiles (UX_UI_SPEC §6). Needs Pillow
and the Inter font (any bold sans works; set ALBUM_ART_FONT to its path).
"""
from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "assets" / "audio" / "catalogue.json"
OUT = ROOT / "assets" / "images" / "albums"
SIZE = 600
FONT = os.environ.get("ALBUM_ART_FONT", "/usr/share/fonts/opentype/inter/Inter-Bold.otf")


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def tile(start: str, end: str, name: str) -> Image.Image:
    a, b = hex_rgb(start), hex_rgb(end)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * (SIZE - 1))
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    # 45 % black scrim over the bottom 42 %, so the white name passes 3:1 on every gradient.
    top = int(SIZE * 0.58)
    draw.rectangle((0, top, SIZE, SIZE), fill=(0, 0, 0, 115))
    img = Image.alpha_composite(img.convert("RGBA"), overlay)
    draw = ImageDraw.Draw(img)
    size = 76
    font = ImageFont.truetype(FONT, size)
    while draw.textlength(name, font=font) > SIZE - 80 and size > 30:
        size -= 4
        font = ImageFont.truetype(FONT, size)
    draw.text((40, SIZE - 52), name, font=font, fill=(255, 255, 255, 255), anchor="ls")
    return img.convert("RGB")


def main() -> int:
    catalogue = json.loads(CATALOGUE.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for album in catalogue["albums"]:
        start, end = album["gradient"]
        tile(start, end, album["shortName"]).save(OUT / f"{album['id']}.png", optimize=True)
    print(f"{len(catalogue['albums'])} album images -> {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
