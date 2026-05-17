#!/bin/bash
# TokenIsland — build a universal macOS .app bundle and a distributable DMG.
# Usage:
#   ./build.sh           # build .app bundle in .build/release/TokenIsland.app
#   ./build.sh --dmg     # also produce TokenIsland.dmg in dist/
#   ./build.sh --ship    # build, package DMG, write SHA256 sums

set -euo pipefail

APP_NAME="TokenIsland"
BRIDGE_NAME="tokenisland-bridge"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="dist"
INFO_PLIST="Info.plist"
APP_ICON="Resources/AppIcon.icns"

if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

MAKE_DMG=false
SHIP=false
for arg in "$@"; do
    case "$arg" in
        --dmg) MAKE_DMG=true ;;
        --ship) MAKE_DMG=true; SHIP=true ;;
        --help|-h)
            sed -n '2,7p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
echo "==> Building $APP_NAME v$VERSION (universal: arm64 + x86_64)"

swift build -c release --arch arm64
swift build -c release --arch x86_64

ARM_DIR=".build/arm64-apple-macosx/release"
X86_DIR=".build/x86_64-apple-macosx/release"

echo "==> Assembling .app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Helpers"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

lipo -create "$ARM_DIR/$APP_NAME" "$X86_DIR/$APP_NAME" \
     -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
lipo -create "$ARM_DIR/$BRIDGE_NAME" "$X86_DIR/$BRIDGE_NAME" \
     -output "$APP_BUNDLE/Contents/Helpers/$BRIDGE_NAME"

cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "$APP_ICON" ]; then
    cp "$APP_ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "Missing app icon at $APP_ICON — run script/generate_app_icon.swift" >&2
    exit 1
fi

# Copy SwiftPM-emitted resource bundle if any
if [ -d "$ARM_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "$ARM_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

echo "==> Embedding Sparkle.framework"
SPARKLE_SRC=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "$SPARKLE_SRC" ]; then
    echo "Missing Sparkle.framework at $SPARKLE_SRC — run swift build at least once" >&2
    exit 1
fi
ditto "$SPARKLE_SRC" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

echo "==> Adding rpath so executables find embedded Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
install_name_tool -add_rpath "@executable_path/../../Frameworks" \
    "$APP_BUNDLE/Contents/Helpers/$BRIDGE_NAME" 2>/dev/null || true

echo "==> Ad-hoc signing (no Apple Developer Program required)"
codesign --force --deep --sign - "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Bundle ready: $APP_BUNDLE"
du -sh "$APP_BUNDLE"

if $MAKE_DMG; then
    mkdir -p "$DIST_DIR"
    DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
    rm -f "$DMG_PATH"

    echo "==> Packaging DMG"
    DMG_STAGE=$(mktemp -d)
    cp -R "$APP_BUNDLE" "$DMG_STAGE/"
    ln -s /Applications "$DMG_STAGE/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
    rm -rf "$DMG_STAGE"

    if $SHIP; then
        echo "==> Writing checksum"
        (cd "$DIST_DIR" && shasum -a 256 "$APP_NAME-$VERSION.dmg" > "$APP_NAME-$VERSION.dmg.sha256")
    fi

    echo "==> DMG ready: $DMG_PATH"
    du -sh "$DMG_PATH"
fi
