#!/usr/bin/env zsh
set -euo pipefail
APP_NAME="GrokBar"
ROOT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/$APP_NAME.app"
MASTER_PNG="$ROOT_DIR/Icon_GrokBar.icon/Assets/icon-1024.png"
ICNS_SRC="$ROOT_DIR/Icon_GrokBar.icns"
ASSETS_CAR_SRC="$ROOT_DIR/dist/icon-assets/Assets.car"

swift build -c release

if [[ -x "$ROOT_DIR/generate_icon.sh" ]] && command -v magick >/dev/null 2>&1; then
	"$ROOT_DIR/generate_icon.sh"
elif [[ ! -f "$MASTER_PNG" ]]; then
	echo "Missing $MASTER_PNG. Install ImageMagick and run ./generate_icon.sh first." >&2
	exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_DIR/Contents/Info.plist"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -f "$ROOT_DIR/grok-small.png" ]]; then
	cp "$ROOT_DIR/grok-small.png" "$APP_DIR/Contents/Resources/grok-small.png"
fi

if [[ -f "$ASSETS_CAR_SRC" ]]; then
	cp "$ASSETS_CAR_SRC" "$APP_DIR/Contents/Resources/Assets.car"
fi

dest_icns="$APP_DIR/Contents/Resources/Icon_GrokBar.icns"
if [[ -f "$ICNS_SRC" ]]; then
	cp "$ICNS_SRC" "$dest_icns"
elif [[ -f "$MASTER_PNG" ]] && command -v iconutil >/dev/null 2>&1; then
	tmpicon=$(mktemp -d)
	mkdir -p "$tmpicon/Icon_GrokBar.iconset"
	for sz in 16 32 64 128 256 512; do
		sips -z "$sz" "$sz" "$MASTER_PNG" --out "$tmpicon/Icon_GrokBar.iconset/icon_${sz}x${sz}.png" >/dev/null
		if [[ $sz -lt 512 ]]; then
			dsz=$((sz * 2))
			sips -z "$dsz" "$dsz" "$MASTER_PNG" --out "$tmpicon/Icon_GrokBar.iconset/icon_${sz}x${sz}@2x.png" >/dev/null
		fi
	done
	iconutil -c icns -o "$dest_icns" "$tmpicon/Icon_GrokBar.iconset"
	rm -rf "$tmpicon"
fi

codesign --force --timestamp=none --sign - --entitlements "$ROOT_DIR/GrokBar.entitlements" "$APP_DIR" || true

echo "Built $APP_DIR"