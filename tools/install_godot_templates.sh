#!/usr/bin/env bash
# Installs the Linux and Windows release export templates for the Godot version
# pinned in .godot-version, verified against tools/godot-<version>.sha512, into
# the directory Godot reads templates from. Prints that directory on stdout.
# Only the two templates we ship are extracted; the full .tpz is ~1.3 GB.
# Re-running is a no-op once installed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
SUMS="$ROOT/tools/godot-$VERSION.sha512"
FILES=(version.txt linux_release.x86_64 windows_release_x86_64.exe)

case "$(uname -s)" in
	Linux) DATA="${XDG_DATA_HOME:-$HOME/.local/share}/godot" ;;
	Darwin) DATA="$HOME/Library/Application Support/Godot" ;;
	MINGW* | MSYS* | CYGWIN*) DATA="$(cygpath -u "$APPDATA")/Godot" ;;
	*) echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac
DEST="$DATA/export_templates/$VERSION.stable"

installed=true
for f in "${FILES[@]}"; do
	[ -f "$DEST/$f" ] || installed=false
done
if $installed; then
	echo "$DEST"
	exit 0
fi

TPZ="Godot_v$VERSION-stable_export_templates.tpz"
EXPECTED="$(awk -v f="$TPZ" '$2 == f { print $1 }' "$SUMS" 2>/dev/null || true)"
if [ -z "$EXPECTED" ]; then
	echo "No checksum for $TPZ in $SUMS. Add its line from the release's SHA512-SUMS.txt." >&2
	exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Godot $VERSION export templates (~1.3 GB)..." >&2
curl -fsSL -o "$TMP/$TPZ" "https://github.com/godotengine/godot/releases/download/$VERSION-stable/$TPZ"

if command -v sha512sum >/dev/null; then
	ACTUAL="$(sha512sum "$TMP/$TPZ" | awk '{ print $1 }')"
else
	ACTUAL="$(shasum -a 512 "$TMP/$TPZ" | awk '{ print $1 }')"
fi
if [ "$ACTUAL" != "$EXPECTED" ]; then
	echo "Checksum mismatch for $TPZ" >&2
	exit 1
fi

mkdir -p "$DEST"
unzip -q -o -j "$TMP/$TPZ" "${FILES[@]/#/templates/}" -d "$DEST"
echo "Installed Godot $VERSION export templates to $DEST" >&2
echo "$DEST"
