#!/usr/bin/env zsh
set -euo pipefail

APP_NAME="GrokBar"
ROOT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR=$(mktemp -d)
STAGING_DIR="$WORK_DIR/staging"
CUSTOM_MOUNT_DIR="$WORK_DIR/mount"
DMG_RW="$WORK_DIR/${APP_NAME}-temp.dmg"
DMG_ASIF="$WORK_DIR/${APP_NAME}-temp.asif"
DMG_OUT="$DIST_DIR/${APP_NAME}.dmg"
VOLUME_NAME="$APP_NAME"
IMAGE_DEVICE=""
MOUNT_DIR=""

cleanup() {
	if [[ -n "$IMAGE_DEVICE" ]]; then
		diskutil eject "$IMAGE_DEVICE" >/dev/null 2>&1 || true
	elif [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]]; then
		hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
	fi
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/build_app.sh"

mkdir -p "$DIST_DIR" "$STAGING_DIR"
rm -f "$DMG_OUT"

cp -R "$ROOT_DIR/$APP_NAME.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if diskutil image create from --help >/dev/null 2>&1; then
	diskutil image create from \
		--format ASIF \
		--volumeName "$VOLUME_NAME" \
		"$STAGING_DIR" \
		"$DMG_ASIF" >/dev/null

	mkdir -p "$CUSTOM_MOUNT_DIR"
	attach_output=$(diskutil image attach --mountPoint "$CUSTOM_MOUNT_DIR" "$DMG_ASIF")
	IMAGE_DEVICE=$(print -r -- "$attach_output" | awk '/^\/dev\// {print $1; exit}')
	if [[ -z "$IMAGE_DEVICE" ]]; then
		echo "Could not determine attached image device." >&2
		exit 1
	fi
	MOUNT_DIR="$CUSTOM_MOUNT_DIR"
else
	hdiutil create \
		-volname "$VOLUME_NAME" \
		-srcfolder "$STAGING_DIR" \
		-ov \
		-format UDRW \
		-fs HFS+ \
		"$DMG_RW" >/dev/null

	MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | grep -o '/Volumes/.*' | head -1)
fi

VOLUME_LABEL=$(basename "$MOUNT_DIR")

osascript <<EOF
tell application "Finder"
	tell disk "$VOLUME_LABEL"
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set bounds of container window to {100, 100, 660, 420}
		set viewOptions to the icon view options of container window
		set arrangement of viewOptions to not arranged
		set icon size of viewOptions to 96
		set position of item "$APP_NAME.app" of container window to {150, 205}
		set position of item "Applications" of container window to {450, 205}
		close
		open
		update without registering applications
		delay 1
	end tell
end tell
EOF

if [[ -n "$IMAGE_DEVICE" ]]; then
	diskutil eject "$IMAGE_DEVICE" >/dev/null
	IMAGE_DEVICE=""
	MOUNT_DIR=""
	diskutil image create from --format UDZO "$DMG_ASIF" "$DMG_OUT" >/dev/null
else
	hdiutil detach "$MOUNT_DIR" -quiet
	MOUNT_DIR=""
	hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" >/dev/null
fi

echo "Built $DMG_OUT"
