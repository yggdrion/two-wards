#!/usr/bin/env bash
# One-time setup of a dev machine; safe to re-run. Installs the pinned Python packages
# (gdtoolkit, pillow, pre-commit), the pinned Godot and gdUnit4, the pre-commit and
# pre-push hooks, then runs the quick check.
# Needs: Python 3 and git on PATH.
# Not installed here: export templates (export.sh fetches them on first use).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PYTHON="$(command -v python3 || command -v python)"

printf '== Python packages\n'
"$PYTHON" -m pip install --disable-pip-version-check -r tools/requirements.txt
printf '\n== Godot\n'
./tools/install_godot.sh >/dev/null
printf '\n== gdUnit4\n'
./tools/install_gdunit4.sh
printf '\n== Bun (lobby and the WebRTC network test)\n'
command -v bun >/dev/null && bun --version || echo "bun not found: install it from https://bun.sh, or the WebRTC network test is skipped"
printf '\n== Git hooks\n'
"$PYTHON" -m pre_commit install
./tools/check.sh --install-hook
./tools/check.sh --quick
printf '\nSetup done. Run ./tools/check.sh for the full check.\n'
