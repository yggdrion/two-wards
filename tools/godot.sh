#!/usr/bin/env bash
# Runs the pinned Godot version, installing it first if needed.
# Example: ./tools/godot.sh --path game
set -euo pipefail

exec "$("$(dirname "$0")/install_godot.sh")" "$@"
