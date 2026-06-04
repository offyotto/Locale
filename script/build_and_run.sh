#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="LocaleApp"
APP_NAME="Locale"
BUNDLE_ID="dev.offyotto.Locale"
DISPLAY_NAME="Locale"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.icon"
ICON_BUILD_DIR="$ROOT_DIR/Resources/IconBuild"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
ASSETS_CAR="$ROOT_DIR/Resources/Assets.car"
PARTIAL_INFO_PLIST="$ROOT_DIR/Resources/IconPartialInfo.plist"

build_app_icon() {
  if [[ ! -d "$ICON_SOURCE" ]]; then
    echo "missing icon source: $ICON_SOURCE" >&2
    exit 1
  fi

  rm -rf "$ICON_BUILD_DIR"
  mkdir -p "$ROOT_DIR/Resources" "$ICON_BUILD_DIR"
  xcrun actool \
    --compile "$ICON_BUILD_DIR" \
    --app-icon AppIcon \
    --output-partial-info-plist "$ICON_BUILD_DIR/partial.plist" \
    --platform macosx \
    --minimum-deployment-target "$MIN_SYSTEM_VERSION" \
    --standalone-icon-behavior all \
    "$ICON_SOURCE" >/dev/null

  cp "$ICON_BUILD_DIR/AppIcon.icns" "$APP_ICON"
  cp "$ICON_BUILD_DIR/Assets.car" "$ASSETS_CAR"
  cp "$ICON_BUILD_DIR/partial.plist" "$PARTIAL_INFO_PLIST"
}

cd "$ROOT_DIR"
pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$PRODUCT_NAME"
build_app_icon

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
cp "$ASSETS_CAR" "$APP_RESOURCES/Assets.car"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>20260603.2</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PRODUCT_NAME" >/dev/null
    ;;
  --build-only|build)
    ;;
  --metrics|metrics)
    open_app
    sleep 3
    PID="$(pgrep -x "$PRODUCT_NAME" | head -n 1)"
    ps -o pid=,rss=,%cpu=,comm= -p "$PID"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  *)
    echo "usage: $0 [run|--verify|--build-only|--metrics|--logs|--debug]" >&2
    exit 2
    ;;
esac
