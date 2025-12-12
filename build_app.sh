#!/usr/bin/env zsh
set -euo pipefail
APP_NAME="GrokBar"
BUNDLE_ID="com.arda.GrokBar"
ROOT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/$APP_NAME.app"

# Build via SwiftPM
swift build -c release

# Create .app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>CFBundleIconFile</key>
	<string>Icon_GrokBar.icns</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>This app embeds grok.com and needs microphone access for voice chat.</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
PLIST

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy resources
if [[ -f "$ROOT_DIR/grok-small.png" ]]; then
	cp "$ROOT_DIR/grok-small.png" "$APP_DIR/Contents/Resources/grok-small.png"
fi
if [[ -f "$ROOT_DIR/Icon_GrokBar.icns" ]]; then
	cp "$ROOT_DIR/Icon_GrokBar.icns" "$APP_DIR/Contents/Resources/Icon_GrokBar.icns"
else
	# Try to build .icns from Icon_GrokBar.icon folder
	if [[ -d "$ROOT_DIR/Icon_GrokBar.icon" ]]; then
		# If a .icns is already inside, copy it
		if [[ -f "$ROOT_DIR/Icon_GrokBar.icon/Icon_GrokBar.icns" ]]; then
			cp "$ROOT_DIR/Icon_GrokBar.icon/Icon_GrokBar.icns" "$APP_DIR/Contents/Resources/Icon_GrokBar.icns"
		else
			# Find the largest PNG inside and generate a proper iconset
			BEST_PNG=$(find "$ROOT_DIR/Icon_GrokBar.icon" -type f -iname '*.png' -print0 2>/dev/null | \
				xargs -0 -I{} sh -c 'w=$(sips -g pixelWidth "$1" 2>/dev/null | awk "/pixelWidth/ {print $2}"); h=$(sips -g pixelHeight "$1" 2>/dev/null | awk "/pixelHeight/ {print $2}"); echo "$((w*h))|$1"' sh {} | \
				sort -nr | head -n1 | cut -d'|' -f2)
			if [[ -n "$BEST_PNG" && -f "$BEST_PNG" ]]; then
				TMPICON=$(mktemp -d)
				mkdir -p "$TMPICON/Icon_GrokBar.iconset"
				for sz in 16 32 64 128 256 512; do
					sips -z $sz $sz "$BEST_PNG" --out "$TMPICON/Icon_GrokBar.iconset/icon_${sz}x${sz}.png" >/dev/null 2>&1 || true
					if [[ $sz -lt 512 ]]; then
						dsz=$((sz*2))
						sips -z $dsz $dsz "$BEST_PNG" --out "$TMPICON/Icon_GrokBar.iconset/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1 || true
					fi
				done
				if command -v iconutil >/dev/null 2>&1; then
					iconutil -c icns -o "$APP_DIR/Contents/Resources/Icon_GrokBar.icns" "$TMPICON/Icon_GrokBar.iconset" || true
				fi
				rm -rf "$TMPICON"
			fi
		fi
	fi

	# If still no .icns, create one from grok-small.png as a last resort
	if [[ ! -f "$APP_DIR/Contents/Resources/Icon_GrokBar.icns" && -f "$ROOT_DIR/grok-small.png" ]]; then
		TMPICON=$(mktemp -d)
		mkdir -p "$TMPICON/Icon_GrokBar.iconset"
		for sz in 16 32 64 128 256 512; do
			sips -z $sz $sz "$ROOT_DIR/grok-small.png" --out "$TMPICON/Icon_GrokBar.iconset/icon_${sz}x${sz}.png" >/dev/null 2>&1 || true
			if [[ $sz -lt 512 ]]; then
				dsz=$((sz*2))
				sips -z $dsz $dsz "$ROOT_DIR/grok-small.png" --out "$TMPICON/Icon_GrokBar.iconset/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1 || true
			fi
		done
		if command -v iconutil >/dev/null 2>&1; then
			iconutil -c icns -o "$APP_DIR/Contents/Resources/Icon_GrokBar.icns" "$TMPICON/Icon_GrokBar.iconset" || true
		fi
		rm -rf "$TMPICON"
	fi
fi

# Codesign ad-hoc to avoid runtime errors
codesign --force --timestamp=none --sign - --entitlements "$ROOT_DIR/GrokBar.entitlements" "$APP_DIR" || true

echo "Built $APP_DIR"
