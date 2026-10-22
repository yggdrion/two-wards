#!/usr/bin/env bash
# Runs all gdUnit4 tests headless with the pinned Godot version.
# Set GODOT_BIN to use your own binary; it must match .godot-version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
GODOT_BIN="${GODOT_BIN:-$("$ROOT/tools/install_godot.sh")}"

ACTUAL="$("$GODOT_BIN" --headless --version)"
case "$ACTUAL" in
	"$VERSION".stable.*) ;;
	*) echo "GODOT_BIN is Godot $ACTUAL, but .godot-version pins $VERSION" >&2; exit 1 ;;
esac

"$ROOT/tools/install_gdunit4.sh"
cd "$ROOT/game"
# Import once so class_name scripts and resources are registered.
"$GODOT_BIN" --headless --import >/dev/null 2>&1
export GODOT_BIN
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests "$@"
