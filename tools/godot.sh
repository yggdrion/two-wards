#!/usr/bin/env bash
# Runs the pinned Godot version, installing it first if needed.
# Example: ./tools/godot.sh --path game
set -euo pipefail

GODOT="$("$(dirname "$0")/install_godot.sh")"
# Running the game skips the class_name scan the editor does, so a checkout that pulled new
# scripts would fail with "Could not find type". Import first; it is quick when up to date.
case " $* " in
	*" -e "* | *" --editor "* | *" --import "*) ;;
	*)
		# Only --path: other args (--quit-after, game args) could cut the import short.
		PATH_ARG=()
		ARGS=("$@")
		for i in "${!ARGS[@]}"; do
			[ "${ARGS[$i]}" = --path ] && PATH_ARG=(--path "${ARGS[$((i + 1))]}")
		done
		"$GODOT" --headless --import "${PATH_ARG[@]}" >/dev/null 2>&1 || true
		;;
esac
exec "$GODOT" "$@"
