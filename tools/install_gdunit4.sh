#!/usr/bin/env bash
# Installs the pinned gdUnit4 version into game/addons/gdUnit4 (gitignored).
set -euo pipefail

GDUNIT4_VERSION="${GDUNIT4_VERSION:-v6.2.2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/game/addons/gdUnit4"

if [ -f "$DEST/plugin.cfg" ] && grep -q "version=\"${GDUNIT4_VERSION#v}\"" "$DEST/plugin.cfg"; then
	echo "gdUnit4 $GDUNIT4_VERSION already installed"
	exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$GDUNIT4_VERSION" \
	https://github.com/godot-gdunit-labs/gdUnit4.git "$TMP/gdunit4"
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -r "$TMP/gdunit4/addons/gdUnit4" "$DEST"
# The addon ships its own test suite; we don't run it.
rm -rf "$DEST/test"
echo "gdUnit4 $GDUNIT4_VERSION installed to $DEST"
