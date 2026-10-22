#!/usr/bin/env bash
# Runs the same checks as CI locally, in CI order, and stops at the first failure:
#   1. gdlint + gdformat --check     2. asset validator + its unittest suite
#   3. gdUnit4 tests (pinned Godot)  4. generated assets are up to date
# Usage: ./tools/check.sh [--quick] [--export] [--install-hook]
#   --quick         only steps 1 and 2 (no Godot), a few seconds
#   --export        also export the Linux and Windows builds to build/<platform>/
#   --install-hook  install a git pre-push hook that runs this script, then exit
# Needs: pip install "gdtoolkit==4.5.0" -r tools/requirements.txt
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

QUICK=false
EXPORT=false
for arg in "$@"; do
	case "$arg" in
		--quick) QUICK=true ;;
		--export) EXPORT=true ;;
		--install-hook)
			HOOK="$(git rev-parse --git-path hooks)/pre-push"
			cp tools/pre-push "$HOOK"
			chmod +x "$HOOK"
			echo "Installed $HOOK (skip once with: git push --no-verify)"
			exit 0
			;;
		*) echo "Usage: $0 [--quick] [--export] [--install-hook]" >&2; exit 2 ;;
	esac
done

PYTHON="$(command -v python3 || command -v python)"
step() { printf '\n== %s\n' "$1"; }

step "Lint and format"
if ! command -v gdlint >/dev/null; then
	echo 'gdlint not found: pip install "gdtoolkit==4.5.0"' >&2
	exit 1
fi
gdlint game/scripts game/tests game/tools
gdformat --check game/scripts game/tests game/tools

step "Asset validator"
"$PYTHON" -m unittest discover -s tools -p "test_*.py"
"$PYTHON" tools/validate_assets.py

if [ "$QUICK" = true ]; then
	printf '\nQuick checks passed (Godot tests skipped).\n'
	exit 0
fi

step "gdUnit4 tests"
./tools/run_tests.sh

step "Generated assets up to date"
# Compare before and after, so local uncommitted work does not count as drift. Content
# diff plus untracked files, not git status: with core.autocrlf, Godot rewriting a CRLF
# checkout as LF shows up as modified in git status although the content is the same.
snapshot() { { git diff game/; git ls-files --others --exclude-standard game/; } | git hash-object --stdin; }
BEFORE="$(snapshot)"
./tools/build_assets.sh >/dev/null
if [ "$(snapshot)" != "$BEFORE" ]; then
	git --no-pager diff --stat game/
	git ls-files --others --exclude-standard game/
	git --no-pager diff game/ | head -n 80
	echo "build_assets changed files under game/: commit the regenerated .tres and .import files." >&2
	exit 1
fi

if [ "$EXPORT" = true ]; then
	step "Export"
	./tools/export.sh linux
	./tools/export.sh windows
fi

printf '\nAll checks passed.\n'
