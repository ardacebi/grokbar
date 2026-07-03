# GrokBar

GrokBar is a native macOS menu-bar wrapper for `grok.com`. It opens as a
top-right panel with a consistent slide animation on every supported macOS
version.

## Requirements

- macOS 13 or newer
- Xcode command-line tools
- ImageMagick (`brew install imagemagick`) for icon generation

## Build and test

```sh
swift test
./build_app.sh
```

The app bundle is written to `GrokBar.app`. To create the drag-to-Applications
disk image, run:

```sh
./build_dmg.sh
```

## Icon assets

The editable icon sources are the SVG files under `Icon_GrokBar.icon/Assets`.
Run `./generate_icon.sh` after changing them. Generated icon intermediates are
ignored by Git; `grok-small.png` remains checked in as the menu-bar resource.
