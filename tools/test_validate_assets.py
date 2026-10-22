"""Tests for validate_assets.py. Run: python -m unittest discover -s tools -p "test_*.py"."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

import validate_assets as va

BLUE = (0x00, 0x99, 0xDB, 255)
OUTLINE = (0x18, 0x14, 0x25, 255)

MANIFEST = {
    "version": 1,
    "assets": [
        {
            "id": "unit_goblin_runner",
            "type": "unit",
            "status": "done",
            "dirs": ["down"],
            "anims": {"walk": {"frames": 2, "fps": 10, "loop": True}},
        },
        {"id": "tile_base", "type": "tileset", "status": "done", "count": 1},
        {"id": "card_art_fireball", "type": "card_art", "status": "todo"},
    ],
}


class ValidateAssetsTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name) / "assets"
        self.root.mkdir()
        self.write_manifest(MANIFEST)
        self.save("units/goblin_runner/unit_goblin_runner_walk_down.png", (64, 32))
        self.save("tiles/base/tile_base_00.png", (16, 16), fill=OUTLINE)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write_manifest(self, manifest: dict) -> None:
        (self.root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def save(self, rel: str, size: tuple[int, int], fill=(0, 0, 0, 0), mode="RGBA") -> Image.Image:
        image = Image.new(mode, size, fill if mode == "RGBA" else fill[:3])
        if mode == "RGBA":
            image.putpixel((0, 0), BLUE)
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
        return image

    def errors(self) -> list[str]:
        return va.validate(self.root)

    def test_valid_set_passes(self) -> None:
        self.assertEqual(self.errors(), [])

    def test_todo_entries_may_be_missing(self) -> None:
        self.assertFalse(any("card_art_fireball" in e for e in self.errors()))

    def test_missing_done_file_is_reported(self) -> None:
        (self.root / "tiles/base/tile_base_00.png").unlink()
        self.assertEqual(self.errors(), ["tiles/base/tile_base_00.png: listed in manifest.json but missing"])

    def test_off_palette_pixel_is_reported_with_position(self) -> None:
        path = self.root / "tiles/base/tile_base_00.png"
        image = Image.open(path).convert("RGBA")
        image.putpixel((3, 5), (1, 2, 3, 255))
        image.save(path)
        [error] = self.errors()
        self.assertIn("1 pixels outside Endesga 32", error)
        self.assertIn("(3,5) #010203", error)

    def test_semi_transparent_pixel_is_reported(self) -> None:
        path = self.root / "units/goblin_runner/unit_goblin_runner_walk_down.png"
        image = Image.open(path)
        image.putpixel((10, 10), (0x00, 0x99, 0xDB, 128))
        image.save(path)
        [error] = self.errors()
        self.assertIn("1 semi-transparent pixels", error)

    def test_strip_width_must_match_frame_count(self) -> None:
        self.save("units/goblin_runner/unit_goblin_runner_walk_down.png", (96, 32))
        self.assertEqual(
            self.errors(),
            ["units/goblin_runner/unit_goblin_runner_walk_down.png: size 96x32, expected 64x32"],
        )

    def test_missing_alpha_channel_is_reported(self) -> None:
        self.save("tiles/base/tile_base_00.png", (16, 16), fill=OUTLINE, mode="RGB")
        self.assertEqual(self.errors(), ["tiles/base/tile_base_00.png: has no alpha channel"])

    def test_bad_names_and_folders(self) -> None:
        self.save("units/hero/unit_hero_walk_left.png", (32, 32))
        self.save("tiles/tile_base_01.png", (16, 16))
        self.save("misc/sprite.png", (16, 16))
        errors = self.errors()
        self.assertIn("unit_hero_walk_left.png: name does not match", errors[2])
        self.assertIn("misc/sprite.png: unknown asset prefix", errors[0])
        self.assertIn("tiles/tile_base_01.png: must live in tiles/base/", errors[1])

    def test_unlisted_file_is_reported(self) -> None:
        self.save("icons/icon_gold.png", (16, 16))
        self.assertEqual(self.errors(), ["icons/icon_gold.png: not listed in manifest.json"])

    def test_bad_manifest_status(self) -> None:
        manifest = json.loads(json.dumps(MANIFEST))
        manifest["assets"][2]["status"] = "wip"
        self.write_manifest(manifest)
        self.assertEqual(len(self.errors()), 1)
        self.assertIn("card_art_fireball has status 'wip'", self.errors()[0])

    def test_repo_assets_pass(self) -> None:
        self.assertEqual(va.validate(va.DEFAULT_ROOT), [])


if __name__ == "__main__":
    unittest.main()
