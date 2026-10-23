#!/usr/bin/env bash
# Installs the pinned webrtc-native GDExtension (WebRTC for desktop Godot) into
# game/addons/webrtc_native (gitignored) and checks its sha256. install_godot.sh runs this,
# so every script that uses the pinned Godot has it. Logs go to stderr.
set -euo pipefail

VERSION="1.2.2-stable"
SHA256="98e9446921740d995bd9ca1be48798dc3c2ceed51e044a25ce18b3cff11f56e5"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/game/addons/webrtc_native"

if [ "$(cat "$DEST/.version" 2>/dev/null)" = "$VERSION" ]; then
	exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading webrtc-native $VERSION..." >&2
curl -fsSL -o "$TMP/webrtc.zip" \
	"https://github.com/godotengine/webrtc-native/releases/download/$VERSION/godot-extension-webrtc_native.zip"
if command -v sha256sum >/dev/null; then
	ACTUAL="$(sha256sum "$TMP/webrtc.zip" | awk '{ print $1 }')"
else
	ACTUAL="$(shasum -a 256 "$TMP/webrtc.zip" | awk '{ print $1 }')"
fi
if [ "$ACTUAL" != "$SHA256" ]; then
	echo "Checksum mismatch for webrtc-native $VERSION" >&2
	exit 1
fi
rm -rf "$DEST"
unzip -q -o "$TMP/webrtc.zip" -d "$TMP/x"
mkdir -p "$(dirname "$DEST")"
mv "$TMP/x/addons/webrtc_native" "$DEST"
echo "$VERSION" > "$DEST/.version"
echo "webrtc-native $VERSION installed to $DEST" >&2
