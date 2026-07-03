#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ICON_DIR="$ROOT_DIR/Icon_GrokBar.icon"
ASSETS_DIR="$ICON_DIR/Assets"
MARK_SVG="$ASSETS_DIR/grok-mark.svg"
MENU_SVG="$ASSETS_DIR/grok-mark-menu.svg"
MARK_LAYER_PNG="$ASSETS_DIR/grok-mark-layer.png"
MASTER_PNG="$ASSETS_DIR/icon-1024.png"
MENU_PNG="$ROOT_DIR/grok-small.png"
ICONSET_DIR="$ASSETS_DIR/Icon_GrokBar.iconset"
ICNS_OUT="$ROOT_DIR/Icon_GrokBar.icns"
ASSETS_CAR_DIR="$ROOT_DIR/dist/icon-assets"
ASSETS_CAR_OUT="$ASSETS_CAR_DIR/Assets.car"
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
ICON_CANVAS_SIZE=824
MASTER_ICON_SIZE=1024
MARK_SIZE=700

for source in "$MARK_SVG" "$MENU_SVG"; do
	if [[ ! -f "$source" ]]; then
		echo "Missing $source" >&2
		exit 1
	fi
done

if ! command -v magick >/dev/null 2>&1; then
	echo "ImageMagick (magick) is required to generate icons." >&2
	exit 1
fi

mkdir -p "$ICONSET_DIR" "$ASSETS_CAR_DIR"

magick -size "${ICON_CANVAS_SIZE}x${ICON_CANVAS_SIZE}" xc:none \
	\( -background none -density 2400 "$MARK_SVG" -colorspace sRGB -type TrueColorAlpha -resize "${MARK_SIZE}x${MARK_SIZE}" \) \
	-gravity center -composite \
	"$MARK_LAYER_PNG"

if [[ -x "$ICTOOL" ]]; then
	ICTOOL_EXPORT="$ASSETS_DIR/icon-${ICON_CANVAS_SIZE}.png"
	"$ICTOOL" "$ICON_DIR" --export-preview macOS Default "$ICON_CANVAS_SIZE" "$ICON_CANVAS_SIZE" 1 -45 "$ICTOOL_EXPORT" >/dev/null
	sips --padToHeightWidth "$MASTER_ICON_SIZE" "$MASTER_ICON_SIZE" "$ICTOOL_EXPORT" --out "$MASTER_PNG" >/dev/null
else
	magick -size "${MASTER_ICON_SIZE}x${MASTER_ICON_SIZE}" xc:'#000000' \
		\( -background none -density 2400 "$MARK_SVG" -colorspace sRGB -type TrueColorAlpha -resize "${MARK_SIZE}x${MARK_SIZE}" \) \
		-gravity center -compose over -composite \
		-colorspace sRGB -type TrueColor -alpha off \
		"$MASTER_PNG"
fi

for sz in 16 32 64 128 256 512; do
	magick "$MASTER_PNG" -resize "${sz}x${sz}" "$ICONSET_DIR/icon_${sz}x${sz}.png"
	if [[ $sz -lt 512 ]]; then
		dsz=$((sz * 2))
		magick "$MASTER_PNG" -resize "${dsz}x${dsz}" "$ICONSET_DIR/icon_${sz}x${sz}@2x.png"
	fi
done

iconutil -c icns -o "$ICNS_OUT" "$ICONSET_DIR"

if command -v actool >/dev/null 2>&1; then
	xcrun actool "$ICON_DIR" \
		--compile "$ASSETS_CAR_DIR" \
		--output-format human-readable-text \
		--notices --warnings --errors \
		--output-partial-info-plist "$ASSETS_CAR_DIR/icon-info.plist" \
		--app-icon Icon \
		--include-all-app-icons \
		--enable-on-demand-resources NO \
		--development-region en \
		--target-device mac \
		--minimum-deployment-target 13.0 \
		--platform macosx >/dev/null
fi

magick -background none -density 1200 "$MENU_SVG" -colorspace sRGB -type TrueColorAlpha -resize 68x66 "$MENU_PNG"

echo "Generated $MARK_LAYER_PNG"
echo "Generated $MASTER_PNG"
echo "Generated $MENU_PNG"
echo "Generated $ICNS_OUT"
[[ -f "$ASSETS_CAR_OUT" ]] && echo "Generated $ASSETS_CAR_OUT"
