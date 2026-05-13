#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TokenIsland"
BRIDGE_NAME="tokenisland-bridge"
BUNDLE_ID="dev.tokenisland.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_HELPERS="$APP_CONTENTS/Helpers"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
INFO_PLIST="$APP_CONTENTS/Info.plist"

SWIFT_BIN="/usr/bin/swift"
ARCH_BIN="/usr/bin/arch"
ARCH_FLAGS=(-arm64)

build_swift() {
  "$ARCH_BIN" "${ARCH_FLAGS[@]}" "$SWIFT_BIN" "$@"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

build_swift build --product "$APP_NAME"
build_swift build --product "$BRIDGE_NAME"
BUILD_BIN_DIR="$(build_swift build --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_HELPERS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
cp "$BUILD_BIN_DIR/$APP_NAME" "$APP_MACOS/$APP_NAME"
cp "$BUILD_BIN_DIR/$BRIDGE_NAME" "$APP_HELPERS/$BRIDGE_NAME"
chmod +x "$APP_MACOS/$APP_NAME" "$APP_HELPERS/$BRIDGE_NAME"

if [[ -d "$BUILD_BIN_DIR/Sparkle.framework" ]]; then
  ditto "$BUILD_BIN_DIR/Sparkle.framework" "$APP_FRAMEWORKS/Sparkle.framework"
elif [[ -d "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" ]]; then
  ditto "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$APP_FRAMEWORKS/Sparkle.framework"
else
  echo "Missing Sparkle.framework; run swift build for TokenIsland first" >&2
  exit 1
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_MACOS/$APP_NAME" 2>/dev/null || true

codesign --force --deep --sign - "$APP_FRAMEWORKS/Sparkle.framework" >/dev/null
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_MACOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
