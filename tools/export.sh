#!/usr/bin/env bash
# Exports a release build with the pinned Godot version and export templates.
# Usage: ./tools/export.sh <linux|windows> [output dir, default build/<platform>]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
	linux) PRESET="Linux"; FILE="two-wards.x86_64" ;;
	windows) PRESET="Windows Desktop"; FILE="two-wards.exe" ;;
	*) echo "Usage: $0 <linux|windows> [output dir]" >&2; exit 1 ;;
esac
OUT="${2:-$ROOT/build/$1}"

GODOT_BIN="$("$ROOT/tools/install_godot.sh")"
"$ROOT/tools/install_godot_templates.sh" >/dev/null

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
cd "$ROOT/game"
# Import once so class_name scripts and resources are registered.
"$GODOT_BIN" --headless --import >/dev/null 2>&1
"$GODOT_BIN" --headless --export-release "$PRESET" "$OUT/$FILE"
# Godot can exit 0 after a failed export, so check the result.
if [ ! -s "$OUT/$FILE" ]; then
	echo "Export of $PRESET produced no $OUT/$FILE" >&2
	exit 1
fi
echo "Exported $PRESET to $OUT/$FILE"
