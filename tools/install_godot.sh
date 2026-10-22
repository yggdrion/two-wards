#!/usr/bin/env bash
# Downloads the Godot version pinned in .godot-version into .tools/godot/<version>/
# (gitignored), verifies it against tools/godot-<version>.sha512, and prints the
# binary path on stdout. Logs go to stderr. Re-running is a no-op once installed.
#
# Supported hosts: Linux x86_64/arm64, macOS, Windows (Git Bash).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
SUMS="$ROOT/tools/godot-$VERSION.sha512"
DEST="$ROOT/.tools/godot/$VERSION"

case "$(uname -s)-$(uname -m)" in
	Linux-x86_64) ASSET="linux.x86_64"; BIN="Godot_v$VERSION-stable_linux.x86_64" ;;
	Linux-aarch64 | Linux-arm64) ASSET="linux.arm64"; BIN="Godot_v$VERSION-stable_linux.arm64" ;;
	Darwin-*) ASSET="macos.universal"; BIN="Godot.app/Contents/MacOS/Godot" ;;
	MINGW*-x86_64 | MSYS*-x86_64 | CYGWIN*-x86_64)
		ASSET="win64.exe"; BIN="Godot_v$VERSION-stable_win64_console.exe" ;;
	*) echo "Unsupported platform: $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac

if [ -x "$DEST/$BIN" ]; then
	echo "$DEST/$BIN"
	exit 0
fi

if [ ! -f "$SUMS" ]; then
	echo "Missing $SUMS. Add the SHA512 lines for Godot $VERSION from its release's SHA512-SUMS.txt." >&2
	exit 1
fi

ZIP="Godot_v$VERSION-stable_$ASSET.zip"
EXPECTED="$(awk -v f="$ZIP" '$2 == f { print $1 }' "$SUMS")"
if [ -z "$EXPECTED" ]; then
	echo "No checksum for $ZIP in $SUMS" >&2
	exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Godot $VERSION ($ASSET)..." >&2
curl -fsSL -o "$TMP/$ZIP" "https://github.com/godotengine/godot/releases/download/$VERSION-stable/$ZIP"

if command -v sha512sum >/dev/null; then
	ACTUAL="$(sha512sum "$TMP/$ZIP" | awk '{ print $1 }')"
else
	ACTUAL="$(shasum -a 512 "$TMP/$ZIP" | awk '{ print $1 }')"
fi
if [ "$ACTUAL" != "$EXPECTED" ]; then
	echo "Checksum mismatch for $ZIP" >&2
	exit 1
fi

mkdir -p "$DEST"
unzip -q -o "$TMP/$ZIP" -d "$DEST"
chmod +x "$DEST/$BIN"
echo "Installed Godot $VERSION to $DEST" >&2
echo "$DEST/$BIN"
