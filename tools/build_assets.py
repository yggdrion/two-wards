"""Rebuilds the SpriteFrames and TileSet resources in game/resources/generated/ from the
PNGs listed in game/assets/manifest.json, using the pinned Godot version.
"""

from _common import GAME, godot, godot_import, run

godot_bin = godot()
# Import first so new or changed PNGs are loadable.
godot_import(godot_bin)
run(godot_bin, "--headless", "--script", "res://tools/build_assets.gd", cwd=GAME)
