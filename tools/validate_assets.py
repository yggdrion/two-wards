#!/usr/bin/env python3
"""Validates every PNG under game/assets/ against the style guide in docs/PLAN.md.

Checks: file name and folder, size per asset type, Endesga 32 palette only, hard
transparency (alpha 0 or 255), and agreement with game/assets/manifest.json.

Usage (Linux, macOS, Windows):
    python tools/validate_assets.py            # py tools\\validate_assets.py on Windows
    python tools/validate_assets.py --root some/other/assets

Exits 1 and lists every problem if anything fails. Needs Pillow.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
DEFAULT_ROOT = REPO / "game" / "assets"
PALETTE_FILE = Path(__file__).resolve().parent / "endesga32.hex"

UNIT_FRAME = 32
TILE_SIZE = (16, 16)
CARD_ART_SIZE = (64, 48)
ICON_SIZE = (16, 16)

# Prefix -> (folder under the asset root, file name pattern).
NAME_RULES = {
    "unit": ("units/<name>", re.compile(r"^unit_([a-z0-9_]+?)_([a-z]+)_(down|up|side)\.png$")),
    "tile": ("tiles/<set>", re.compile(r"^tile_([a-z0-9]+)_(\d{2})\.png$")),
    "card_art": ("cards", re.compile(r"^card_art_([a-z0-9_]+)\.png$")),
    "icon": ("icons", re.compile(r"^icon_([a-z0-9_]+)\.png$")),
}
STATUSES = {"todo", "placeholder", "done"}
MAX_PIXEL_REPORTS = 5


def load_palette(path: Path = PALETTE_FILE) -> set[tuple[int, int, int]]:
    colors = set()
    for line in path.read_text(encoding="utf-8").split():
        colors.add((int(line[0:2], 16), int(line[2:4], 16), int(line[4:6], 16)))
    return colors


def expected_files(entry: dict) -> dict[str, tuple[int, int]]:
    """Maps each relative PNG path a manifest entry needs to its exact size."""
    asset_id = entry["id"]
    kind = entry["type"]
    if kind == "unit":
        name = asset_id.removeprefix("unit_")
        files = {}
        for anim, spec in entry["anims"].items():
            for direction in entry["dirs"]:
                path = f"units/{name}/{asset_id}_{anim}_{direction}.png"
                files[path] = (UNIT_FRAME * spec["frames"], UNIT_FRAME)
        return files
    if kind == "tileset":
        tile_set = asset_id.removeprefix("tile_")
        return {f"tiles/{tile_set}/{asset_id}_{n:02d}.png": TILE_SIZE for n in range(entry["count"])}
    if kind == "card_art":
        return {f"cards/{asset_id}.png": CARD_ART_SIZE}
    if kind == "icon":
        return {f"icons/{asset_id}.png": ICON_SIZE}
    raise ValueError(f"unknown asset type {kind!r}")


def check_name(rel: str) -> str | None:
    path = Path(rel)
    for prefix, (folder, pattern) in NAME_RULES.items():
        if not path.name.startswith(prefix + "_"):
            continue
        match = pattern.match(path.name)
        if not match:
            return f"{rel}: name does not match the {prefix} pattern {pattern.pattern}"
        want = folder.replace("<name>", match.group(1)).replace("<set>", match.group(1))
        if path.parent.as_posix() != want:
            return f"{rel}: must live in {want}/"
        return None
    return f"{rel}: unknown asset prefix (expected unit_, tile_, card_art_ or icon_)"


def check_pixels(rel: str, image: Image.Image, palette: set[tuple[int, int, int]]) -> list[str]:
    errors = []
    rgba = image.convert("RGBA")
    width = rgba.width
    soft, off = [], []
    data = rgba.tobytes()
    for i in range(0, len(data), 4):
        r, g, b, a = data[i : i + 4]
        if a == 0:
            continue
        xy = ((i // 4) % width, (i // 4) // width)
        if a != 255:
            soft.append(xy)
        if (r, g, b) not in palette:
            off.append((xy, f"#{r:02x}{g:02x}{b:02x}"))
    if soft:
        sample = ", ".join(f"({x},{y})" for x, y in soft[:MAX_PIXEL_REPORTS])
        errors.append(f"{rel}: {len(soft)} semi-transparent pixels, e.g. {sample}")
    if off:
        sample = ", ".join(f"({x},{y}) {c}" for (x, y), c in off[:MAX_PIXEL_REPORTS])
        errors.append(f"{rel}: {len(off)} pixels outside Endesga 32, e.g. {sample}")
    return errors


def validate(root: Path = DEFAULT_ROOT, palette: set[tuple[int, int, int]] | None = None) -> list[str]:
    palette = palette if palette is not None else load_palette()
    errors: list[str] = []

    manifest_path = root / "manifest.json"
    expected: dict[str, tuple[int, int]] = {}
    required: set[str] = set()
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        seen_ids = set()
        for entry in manifest.get("assets", []):
            asset_id = entry.get("id", "?")
            if asset_id in seen_ids:
                errors.append(f"manifest: duplicate id {asset_id}")
            seen_ids.add(asset_id)
            if entry.get("status") not in STATUSES:
                errors.append(f"manifest: {asset_id} has status {entry.get('status')!r}, expected one of {sorted(STATUSES)}")
            try:
                files = expected_files(entry)
            except (KeyError, ValueError) as exc:
                errors.append(f"manifest: {asset_id} is malformed ({exc})")
                continue
            expected.update(files)
            if entry.get("status") in ("placeholder", "done"):
                required.update(files)
    else:
        errors.append(f"{manifest_path.relative_to(root.parent)}: missing")

    present = set()
    for png in sorted(root.rglob("*.png")):
        rel = png.relative_to(root).as_posix()
        present.add(rel)
        name_error = check_name(rel)
        if name_error:
            errors.append(name_error)
            continue
        if rel not in expected:
            errors.append(f"{rel}: not listed in manifest.json")
        with Image.open(png) as image:
            want = expected.get(rel)
            if want and image.size != want:
                errors.append(f"{rel}: size {image.size[0]}x{image.size[1]}, expected {want[0]}x{want[1]}")
            if image.mode not in ("RGBA", "PA", "LA") and "transparency" not in image.info:
                errors.append(f"{rel}: has no alpha channel")
            errors.extend(check_pixels(rel, image, palette))

    for rel in sorted(required - present):
        errors.append(f"{rel}: listed in manifest.json but missing")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="asset folder (default: game/assets)")
    args = parser.parse_args(argv)
    if not args.root.is_dir():
        print(f"No asset folder at {args.root}, nothing to validate.")
        return 0
    errors = validate(args.root)
    for error in errors:
        print(error)
    count = len(list(args.root.rglob("*.png")))
    if errors:
        print(f"\n{len(errors)} problem(s) in {count} PNG file(s).")
        return 1
    print(f"All {count} PNG file(s) pass.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
