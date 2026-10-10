#!/usr/bin/env python3
"""Composes the store screenshots and the Play feature graphic (store assets, P7).

    flutter test test_screenshots/store_test.dart     # renders build/store_raw/
    python3 tool/store_screenshots.py                 # writes store/screenshots/, store/graphics/

Each raw screen (rendered by the app itself at the device's size, with its safe areas) gets the
device's status bar and home indicator, a device frame, and a caption above it, on the brand
background. Sizes are the ones the stores ask for (store/README.md):

    App Store   iPhone 6.9"  1320 x 2868     iPad 13"  2064 x 2752
    Google Play phone 1080 x 1920 (9:16)     7" tablet 1080 x 1920     10" tablet 1440 x 2560

The words come from CAPTIONS below. Images have no transparency (both stores reject it).
Fonts: Inter (for iOS) and Roboto (for Android); set STORE_FONTS to a folder holding both if
they are not in the default places.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "build" / "store_raw"
OUT = ROOT / "store"
ICON = ROOT / "assets" / "branding" / "store" / "app-store-1024.png"

# --- Words ---------------------------------------------------------------------------------
# (headline, subline); "wide" variants are used where a tablet shows a different screen.
CAPTIONS = {
    "01-steps": ("Work the Twelve Steps", "A clear guide to every step and tradition"),
    "02-step-guide": ("Practical guidance for each step", "Read at your own pace, at any text size"),
    "02-step-guide/wide": ("Prayers and readings", "Just for Today, the Promises and more"),
    "03-big-book": ("The Big Book", "Every chapter, and both editions of the stories"),
    "04-audio": ("Over 90 hours of recovery audio", "Big Book studies and speaker recordings"),
    "05-listen": ("Listen and read along", "Transcripts for the Big Book recordings"),
    "06-recovery": ("Count your days", "With prayers, readings and daily reflections"),
    "06-recovery/wide": ("Count your days", "Your recovery date stays on your device"),
    "07-reminders": ("A gentle reminder each hour", "Each one opens a thought for the hour"),
    "08-dark": ("Easy on the eyes, day or night", "Light and dark themes"),
}

# --- Output sizes and frame geometry per device ----------------------------------------------
# canvas: store image size. bezel/radius: fractions of the raw screen width. island: iPhone
# Dynamic Island in points (w, h, top). camera: Android punch hole diameter in dp.
DEVICES = {
    "iphone-6.9": dict(store="app-store/iphone-6.9", canvas=(1320, 2868), bezel=0.034,
                       radius=0.142, island=(126, 37, 11), kind="iphone"),
    "ipad-13": dict(store="app-store/ipad-13", canvas=(2064, 2752), bezel=0.026, radius=0.030,
                    kind="ipad", caption_base=1376),
    "android-phone": dict(store="google-play/phone", canvas=(1080, 1920), bezel=0.032,
                          radius=0.085, camera=12, kind="android"),
    "android-tablet-7": dict(store="google-play/tablet-7", canvas=(1080, 1920), bezel=0.03,
                             radius=0.035, kind="android-tablet"),
    "android-tablet-10": dict(store="google-play/tablet-10", canvas=(1440, 2560), bezel=0.026,
                              radius=0.03, kind="android-tablet"),
}

# Brand colours (UX_UI_SPEC §3).
NAVY = (30, 33, 52)
INK = (22, 26, 38)
INK_2 = (74, 81, 99)
WHITE = (255, 255, 255)
MIST = (182, 188, 203)
LIGHT_BG = ((238, 245, 255), (214, 228, 255))
DARK_BG = ((34, 38, 62), (11, 13, 20))
FRAME = (16, 18, 24)
FRAME_EDGE = (58, 63, 78)


def font_dirs() -> list[Path]:
    dirs = [Path(os.environ["STORE_FONTS"])] if os.environ.get("STORE_FONTS") else []
    flutter = os.environ.get("FLUTTER_ROOT", "/opt/sdk/flutter")
    return dirs + [
        Path("/usr/share/fonts/opentype/inter"),
        Path(flutter) / "bin/cache/artifacts/material_fonts",
        Path.home() / "Library/Fonts",
        Path("/Library/Fonts"),
    ]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    for d in font_dirs():
        for ext in (".otf", ".ttf"):
            p = d / f"{name}{ext}"
            if p.exists():
                return ImageFont.truetype(str(p), size)
    sys.exit(f"Font {name} not found; set STORE_FONTS to a folder with Inter and Roboto")


# --- Drawing helpers ---------------------------------------------------------------------------
def gradient(size: tuple[int, int], top: tuple, bottom: tuple) -> Image.Image:
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return col.resize((w, h))


def rounded_mask(size: tuple[int, int], radius: float) -> Image.Image:
    k = 4
    big = Image.new("L", (size[0] * k, size[1] * k), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, size[0] * k - 1, size[1] * k - 1), radius=radius * k, fill=255,
    )
    return big.resize(size, Image.LANCZOS)


class Overlay:
    """Draws anti-aliased shapes: everything is drawn 4x larger, then scaled down."""

    K = 4

    def __init__(self, size: tuple[int, int]):
        self.size = size
        self.img = Image.new("RGBA", (size[0] * self.K, size[1] * self.K), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def s(self, *v: float):
        return [x * self.K for x in v]

    def rrect(self, box, r, fill=None, outline=None, width=0):
        self.d.rounded_rectangle(self.s(*box), radius=r * self.K, fill=fill, outline=outline,
                                 width=int(width * self.K))

    def ellipse(self, box, fill=None, outline=None, width=0):
        self.d.ellipse(self.s(*box), fill=fill, outline=outline, width=int(width * self.K))

    def arc(self, box, start, end, fill, width):
        self.d.arc(self.s(*box), start, end, fill=fill, width=int(width * self.K))

    def pieslice(self, box, start, end, fill):
        self.d.pieslice(self.s(*box), start, end, fill=fill)

    def polygon(self, pts, fill):
        self.d.polygon([(x * self.K, y * self.K) for x, y in pts], fill=fill)

    def text(self, xy, s, fnt_name, size, fill, anchor="lm"):
        f = font(fnt_name, int(size * self.K))
        self.d.text((xy[0] * self.K, xy[1] * self.K), s, font=f, fill=fill, anchor=anchor)

    def image(self) -> Image.Image:
        return self.img.resize(self.size, Image.LANCZOS)


def signal_bars(o: Overlay, x, cy, u, color):
    """Four rising bars, iOS style; x is the left edge, u one point."""
    w, gap = 3 * u, 1.6 * u
    for i, h in enumerate((4.5, 6.5, 8.5, 11)):
        left = x + i * (w + gap)
        o.rrect((left, cy + 5.5 * u - h * u, left + w, cy + 5.5 * u), 0.8 * u, fill=color)
    return x + 4 * w + 3 * gap


def wifi(o: Overlay, x, cy, u, color):
    """Wi-Fi fan of three bands; x is the left edge."""
    r = 8.2 * u
    cx, by = x + r, cy + 5.3 * u
    for i, rr in enumerate((r, r * 0.66, r * 0.32)):
        if i < 2:
            o.arc((cx - rr, by - rr, cx + rr, by + rr), 225, 315, fill=color, width=2.1 * u)
        else:
            o.pieslice((cx - rr, by - rr, cx + rr, by + rr), 225, 315, fill=color)
    return x + 2 * r


def battery(o: Overlay, x, cy, u, color, level=0.85):
    w, h = 24.5 * u, 11.5 * u
    top = cy - h / 2
    o.rrect((x, top, x + w, top + h), 3.2 * u, outline=color, width=1.1 * u)
    pad = 2 * u
    o.rrect((x + pad, top + pad, x + pad + (w - 2 * pad) * level, top + h - pad), 1.6 * u, fill=color)
    o.rrect((x + w + 1.2 * u, cy - 2 * u, x + w + 2.6 * u, cy + 2 * u), 0.8 * u, fill=color)
    return x + w + 2.6 * u


def android_icons(o: Overlay, right, cy, u, color):
    """Wi-Fi wedge, signal triangle and a vertical battery, Material style; right-aligned."""
    # battery
    bw, bh = 7.5 * u, 13 * u
    bx = right - bw
    o.rrect((bx, cy - bh / 2 + 1.2 * u, bx + bw, cy + bh / 2), 1.3 * u, fill=color)
    o.rrect((bx + 2 * u, cy - bh / 2, bx + bw - 2 * u, cy - bh / 2 + 1.8 * u), 0.5 * u, fill=color)
    # signal triangle
    sx = bx - 6 * u - 13 * u
    o.polygon([(sx, cy + 6.5 * u), (sx + 13 * u, cy + 6.5 * u), (sx + 13 * u, cy - 6.5 * u)], color)
    # wifi wedge
    wx = sx - 6 * u - 16 * u
    o.pieslice((wx, cy - 7 * u, wx + 16 * u, cy + 9 * u), 225, 315, fill=color)
    o.pieslice((wx, cy - 7 * u, wx + 16 * u, cy + 9 * u + 4 * u), 225, 315, fill=color)


def status_bar(screen: Image.Image, dev: dict, man: dict, light: bool) -> None:
    """Paints the system status bar and home indicator into the raw screen's safe areas."""
    w, h = screen.size
    ratio = man["ratio"]
    u = ratio  # one point / dp in pixels
    top = man["safeTop"] * ratio
    bottom = man["safeBottom"] * ratio
    color = WHITE + (255,) if light else (0, 0, 0, 255)
    o = Overlay((w, h))
    kind = dev["kind"]
    if kind == "iphone":
        iw, ih, it = dev["island"]
        cy = it * u + ih * u / 2
        o.rrect((w / 2 - iw * u / 2, it * u, w / 2 + iw * u / 2, it * u + ih * u), ih * u / 2,
                fill=(0, 0, 0, 255))
        o.text((w / 2 - iw * u / 2 - 64 * u, cy), "9:41", "Inter-SemiBold", 17 * u, color, "mm")
        x = w / 2 + iw * u / 2 + 34 * u
        x = signal_bars(o, x, cy, u, color) + 6 * u
        x = wifi(o, x, cy, u, color) + 6 * u
        battery(o, x, cy, u, color)
        o.rrect((w / 2 - 70 * u, h - 8 * u - 5 * u, w / 2 + 70 * u, h - 8 * u), 2.5 * u, fill=color)
    elif kind == "ipad":
        cy = top / 2
        o.text((22 * u, cy), "9:41", "Inter-SemiBold", 13.5 * u, color, "lm")
        o.text((58 * u, cy), "Fri 10 Oct", "Inter-SemiBold", 13.5 * u, color, "lm")
        x = w - 22 * u - 27 * u - 6 * u - 16.4 * u
        wifi(o, x, cy, u * 0.85, color)
        battery(o, w - 22 * u - 27 * u, cy, u * 0.95, color)
        o.rrect((w / 2 - 160 * u, h - 8 * u - 5 * u, w / 2 + 160 * u, h - 8 * u), 2.5 * u, fill=color)
    else:
        cy = top / 2
        o.text((16 * u, cy), "9:41", "Roboto-Medium", 14 * u, color, "lm")
        android_icons(o, w - 16 * u, cy, u, color)
        if dev.get("camera"):
            r = dev["camera"] * u / 2
            o.ellipse((w / 2 - r, cy - r, w / 2 + r, cy + r), fill=(0, 0, 0, 255))
        handle = (54 if kind == "android" else 80) * u
        y = h - bottom / 2
        o.rrect((w / 2 - handle, y - 2 * u, w / 2 + handle, y + 2 * u), 2 * u, fill=color)
    screen.alpha_composite(o.image())


def framed(screen: Image.Image, dev: dict) -> Image.Image:
    """The screen inside a device body with rounded corners, a hairline edge and no alpha
    outside the body (that is filled by the background later)."""
    w, h = screen.size
    b = round(dev["bezel"] * w)
    r_screen = dev["radius"] * w
    body = (w + 2 * b, h + 2 * b)
    out = Image.new("RGBA", body, (0, 0, 0, 0))
    o = Overlay(body)
    o.rrect((0, 0, body[0], body[1]), r_screen + b, fill=FRAME_EDGE + (255,))
    edge = max(2, b * 0.08)
    o.rrect((edge, edge, body[0] - edge, body[1] - edge), r_screen + b - edge, fill=FRAME + (255,))
    out.alpha_composite(o.image())
    out.paste(screen, (b, b), rounded_mask(screen.size, r_screen))
    return out


def shadow(size: tuple[int, int], frame: Image.Image, at: tuple[int, int], dark: bool):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    alpha = frame.getchannel("A").point(lambda a: int(a * (0.55 if dark else 0.28)))
    blob = Image.new("RGBA", frame.size, (8, 12, 30, 255))
    blob.putalpha(alpha)
    offset = round(frame.size[1] * 0.012)
    layer.paste(blob, (at[0], at[1] + offset), blob)
    return layer.filter(ImageFilter.GaussianBlur(radius=max(8, frame.size[0] * 0.025)))


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt, max_width: float) -> list[str]:
    words, lines, line = text.split(), [], ""
    for w in words:
        trial = f"{line} {w}".strip()
        if draw.textlength(trial, font=fnt) <= max_width or not line:
            line = trial
        else:
            lines.append(line)
            line = w
    lines.append(line)
    return lines


def compose(raw: Path, dev_id: str, man: dict, shot: dict) -> Image.Image:
    dev = DEVICES[dev_id]
    W, H = dev["canvas"]
    dark = shot["theme"] == "dark"
    wide = dev_id == "ipad-13"
    key = f"{shot['id']}/wide" if wide and f"{shot['id']}/wide" in CAPTIONS else shot["id"]
    headline, subline = CAPTIONS[key]

    canvas = gradient((W, H), *(DARK_BG if dark else LIGHT_BG)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Caption: sized from the canvas width, capped for the wide tablet canvases.
    base = dev.get("caption_base", min(W, H * 0.62))
    h_size, s_size = round(base * 0.072), round(base * 0.04)
    h_font, s_font = font("Inter-Bold", h_size), font("Inter-Medium", s_size)
    # The caption block has room for two lines of each, so every device sits at the same
    # height whatever the caption's length; shorter captions are centred in the block.
    h_lines = wrap(draw, headline, h_font, W * 0.86)[:2]
    s_lines = wrap(draw, subline, s_font, W * 0.84)[:2]
    h_step, s_step, between = round(h_size * 1.16), round(s_size * 1.3), round(s_size * 0.45)
    block_top = round(H * 0.045)
    block = 2 * h_step + between + 2 * s_step
    used = len(h_lines) * h_step + between + len(s_lines) * s_step
    y = block_top + (block - used) // 2
    for line in h_lines:
        draw.text((W / 2, y), line, font=h_font, fill=WHITE if dark else INK, anchor="mt")
        y += h_step
    y += between
    for line in s_lines:
        draw.text((W / 2, y), line, font=s_font, fill=MIST if dark else INK_2, anchor="mt")
        y += s_step
    y = block_top + block

    # The device, as large as fits below the caption.
    screen = Image.open(raw).convert("RGBA")
    status_bar(screen, dev, man, shot["lightStatusBar"])
    frame = framed(screen, dev)
    top = y + round(H * 0.035)
    avail_w, avail_h = W * (0.84 if wide else 0.8), H - top - round(H * 0.04)
    scale = min(avail_w / frame.size[0], avail_h / frame.size[1])
    frame = frame.resize((round(frame.size[0] * scale), round(frame.size[1] * scale)), Image.LANCZOS)
    at = ((W - frame.size[0]) // 2, top)
    canvas.alpha_composite(shadow((W, H), frame, at, dark))
    canvas.alpha_composite(frame, at)
    return canvas.convert("RGB")


def feature_graphic() -> Image.Image:
    """Google Play feature graphic, 1024 x 500: the icon, the name, one line, and two phones."""
    W, H = 1024, 500
    canvas = gradient((W, H), (126, 222, 255), (47, 98, 216)).convert("RGBA")
    # Diagonal light: blend a horizontal gradient over the vertical one.
    across = Image.linear_gradient("L").rotate(90).resize((W, H))
    tint = Image.new("RGBA", (W, H), (36, 81, 199, 255))
    tint.putalpha(across.point(lambda a: int(a * 0.55)))
    canvas.alpha_composite(tint)

    icon = Image.open(ICON).convert("RGBA").resize((132, 132), Image.LANCZOS)
    mask = rounded_mask(icon.size, 30)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow.paste(Image.new("RGBA", icon.size, (10, 20, 60, 110)), (64, 80 + 8), mask)
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
    canvas.paste(icon, (64, 80), mask)

    draw = ImageDraw.Draw(canvas)
    draw.text((64, 246), "12 Step Guide", font=font("Inter-Bold", 60), fill=WHITE, anchor="lt")
    lines = ["The Steps, the Big Book and", "over 90 hours of recovery audio"]
    for i, line in enumerate(lines):
        draw.text((66, 330 + i * 38), line, font=font("Inter-Medium", 28), fill=(234, 242, 255),
                  anchor="lt")

    # Two phones on the right, cropped by the bottom edge.
    shots = [RAW / "android-phone" / "01-steps.png", RAW / "android-phone" / "05-listen.png"]
    man = json.loads((RAW / "android-phone" / "manifest.json").read_text())
    dev = DEVICES["android-phone"]
    for i, (p, light) in enumerate(zip(shots, (False, True))):
        screen = Image.open(p).convert("RGBA")
        status_bar(screen, dev, man, light)
        frame = framed(screen, dev)
        target_h = 470
        frame = frame.resize((round(frame.size[0] * target_h / frame.size[1]), target_h),
                             Image.LANCZOS)
        x = 560 + i * 222
        y = 60 - i * 34 + 40
        canvas.alpha_composite(shadow((W, H), frame, (x, y), True))
        canvas.alpha_composite(frame, (x, y))
    return canvas.convert("RGB")


def contact_sheet(images: list[Path], out: Path, height: int = 640) -> None:
    thumbs = [Image.open(p).convert("RGB") for p in images]
    thumbs = [t.resize((round(t.width * height / t.height), height), Image.LANCZOS) for t in thumbs]
    gap = 16
    sheet = Image.new("RGB", (sum(t.width for t in thumbs) + gap * (len(thumbs) + 1), height + 2 * gap),
                      (60, 64, 76))
    x = gap
    for t in thumbs:
        sheet.paste(t, (x, gap))
        x += t.width + gap
    sheet.save(out, quality=88)


def main() -> int:
    if not RAW.exists():
        sys.exit("No raw screens: run  flutter test test_screenshots/store_test.dart  first")
    written = []
    for dev_id in DEVICES:
        mf = RAW / dev_id / "manifest.json"
        if not mf.exists():
            print(f"skip {dev_id}: no raw screens")
            continue
        man = json.loads(mf.read_text())
        dest = OUT / "screenshots" / DEVICES[dev_id]["store"]
        dest.mkdir(parents=True, exist_ok=True)
        for old in dest.glob("*.png"):
            old.unlink()
        for shot in man["shots"]:
            img = compose(RAW / dev_id / f"{shot['id']}.png", dev_id, man, shot)
            path = dest / f"{shot['id']}.png"
            img.save(path, optimize=True)
            written.append(path)
        contact_sheet(sorted(dest.glob("*.png")), OUT / "previews" / f"{dev_id}.jpg")
        print(f"{dev_id}: {len(man['shots'])} screenshots -> {dest.relative_to(ROOT)}")
    graphics = OUT / "graphics"
    graphics.mkdir(parents=True, exist_ok=True)
    if (RAW / "android-phone" / "manifest.json").exists():
        feature_graphic().save(graphics / "google-play-feature-graphic-1024x500.png", optimize=True)
        print("feature graphic -> store/graphics/google-play-feature-graphic-1024x500.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
