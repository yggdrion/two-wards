#!/usr/bin/env python3
"""Draws placeholder PNGs for every manifest entry with status "placeholder".

The placeholders follow the style guide (Endesga 32, hard alpha, dark outline on
units). They are drawn at the old 320x180 sizes and scaled up 2x to the sizes the
validator expects so the validator and the Godot import script can be exercised
long before real art exists. Entries marked "done" and files listed in an
entry's "final" array are never touched.

Usage (Linux, macOS, Windows):
    python tools/make_placeholders.py          # py tools\\make_placeholders.py on Windows

Output is deterministic: running it twice produces identical files. Needs Pillow.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_assets import DEFAULT_ROOT, expected_files  # noqa: E402

# Placeholders are drawn on a half-size grid and scaled up to the validator's sizes.
UNIT_FRAME = 32

# Endesga 32 colors, named by use.
OUTLINE = "#181425"
WHITE = "#ffffff"
YELLOW = "#fee761"
RED = "#e43b44"
ORANGE = "#f77622"
SKIN = "#e8b796"
BROWN = "#733e39"
UNIT_COLORS = {
    # body, body shade, accent (eyes or gem)
    "hero": ("#0099db", "#124e89", "#2ce8f5"),
    "goblin_runner": ("#63c74d", "#3e8948", RED),
}
NEUTRAL = ("#8b9bb4", "#5a6988", WHITE)
TILE_COLORS = ["#3a4466", "#262b44", "#5a6988", "#193c3e"]


def draw_unit(name: str, anim: str, direction: str, frames: int) -> Image.Image:
    body, shade, accent = UNIT_COLORS.get(name, NEUTRAL)
    strip = Image.new("RGBA", (UNIT_FRAME * frames, UNIT_FRAME), (0, 0, 0, 0))
    draw = ImageDraw.Draw(strip)
    for f in range(frames):
        ox = f * UNIT_FRAME
        bob = 1 if anim == "idle" and f % 2 else 0
        step = (f % 2) * 2 - 1 if anim == "walk" else 0
        top = 8 + bob
        # Feet alternate on walk.
        draw.rectangle((ox + 11 + step, 26, ox + 14 + step, 29), fill=shade, outline=OUTLINE)
        draw.rectangle((ox + 17 - step, 26, ox + 20 - step, 29), fill=shade, outline=OUTLINE)
        # Body with light from the top-left: shade on the bottom-right half.
        draw.rectangle((ox + 9, top + 6, ox + 22, 27), fill=body, outline=OUTLINE)
        draw.rectangle((ox + 16, top + 13, ox + 21, 26), fill=shade)
        # Head.
        draw.rectangle((ox + 10, top - 3, ox + 21, top + 7), fill=body, outline=OUTLINE)
        if direction == "down":
            draw.point([(ox + 13, top + 2), (ox + 18, top + 2)], fill=accent)
        elif direction == "side":
            draw.point([(ox + 19, top + 2)], fill=accent)
        # Attack: a weapon swings out to the right, peaking mid-animation.
        if anim == "attack":
            reach = min(f, frames - 1 - f) * 2 + 2
            draw.rectangle((ox + 22, top + 9, ox + 22 + reach, top + 11), fill=accent, outline=OUTLINE)
    return strip


def draw_tile(index: int) -> Image.Image:
    color = TILE_COLORS[index % len(TILE_COLORS)]
    tile = Image.new("RGBA", (16, 16), color)
    draw = ImageDraw.Draw(tile)
    # Low-contrast speckle so the tiling is visible; no outline on terrain.
    detail = TILE_COLORS[(index + 1) % len(TILE_COLORS)]
    draw.point([(3, 4), (11, 2), (7, 10), (13, 13), (2, 12)], fill=detail)
    return tile


def draw_card_art() -> Image.Image:
    art = Image.new("RGBA", (64, 48), "#262b44")
    draw = ImageDraw.Draw(art)
    draw.rectangle((0, 34, 63, 47), fill="#3a4466")
    draw.rectangle((24, 12, 39, 40), fill="#8b9bb4", outline=OUTLINE)
    draw.rectangle((32, 13, 38, 39), fill="#5a6988")
    draw.rectangle((21, 8, 42, 13), fill=BROWN, outline=OUTLINE)
    draw.line((44, 10, 58, 4), fill=YELLOW)
    return art


def draw_icon() -> Image.Image:
    icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    draw.polygon([(9, 1), (3, 9), (7, 9), (6, 15), (13, 6), (9, 6)], fill=YELLOW, outline=ORANGE)
    return icon


def render(entry: dict, rel: str) -> Image.Image:
    kind = entry["type"]
    if kind == "unit":
        stem = Path(rel).stem.removeprefix(entry["id"] + "_")
        anim, direction = stem.rsplit("_", 1)
        name = entry["id"].removeprefix("unit_")
        return draw_unit(name, anim, direction, entry["anims"][anim]["frames"])
    if kind == "tileset":
        return draw_tile(int(Path(rel).stem.rsplit("_", 1)[1]))
    if kind == "card_art":
        return draw_card_art()
    if kind == "icon":
        return draw_icon()
    raise ValueError(f"no placeholder for type {kind!r}")


def main(root: Path = DEFAULT_ROOT) -> int:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    written = 0
    for entry in manifest["assets"]:
        if entry["status"] != "placeholder":
            continue
        for rel, size in expected_files(entry).items():
            # Real art for part of an entry (e.g. one direction) is listed in "final".
            if rel in entry.get("final", []):
                continue
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            render(entry, rel).resize(size, Image.Resampling.NEAREST).save(path, optimize=True)
            written += 1
    print(f"Wrote {written} placeholder PNG file(s) under {root}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
