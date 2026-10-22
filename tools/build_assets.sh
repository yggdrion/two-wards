#!/usr/bin/env bash
# Rebuilds SpriteFrames and TileSet resources in game/resources/generated/ from the
# PNGs listed in game/assets/manifest.json, using the pinned Godot version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$("$ROOT/tools/install_godot.sh")}"

cd "$ROOT/game"
# Import first so new or changed PNGs are loadable.
"$GODOT_BIN" --headless --import >/dev/null 2>&1
"$GODOT_BIN" --headless --script res://tools/build_assets.gd
