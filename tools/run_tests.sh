#!/usr/bin/env bash
# Runs all gdUnit4 tests headless. Needs GODOT_BIN pointing at Godot 4.7.2.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

"$ROOT/tools/install_gdunit4.sh"
cd "$ROOT/game"
# Import once so class_name scripts and resources are registered.
"$GODOT_BIN" --headless --import >/dev/null 2>&1
export GODOT_BIN
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -a res://tests "$@"
