#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/${CONFIGURATION}"
APP_NAME="katalk-ax.app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME"
EXECUTABLE_NAME="katalk-ax-menu-bar"
ICON_NAME="katalk-ax.icns"

mkdir -p "$ROOT_DIR/dist"

ICON_WORK_DIR="$(mktemp -d "$ROOT_DIR/dist/menu-bar-icons.XXXXXX")"
ICONSET_DIR="$ICON_WORK_DIR/katalk-ax.iconset"

trap 'rm -rf "$ICON_WORK_DIR"' EXIT

swift build -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"
mkdir -p "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/generate-app-iconset.swift" --output-dir "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_WORK_DIR/$ICON_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/packaging/macos/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_WORK_DIR/$ICON_NAME" "$APP_DIR/Contents/Resources/$ICON_NAME"

plutil -replace CFBundleShortVersionString -string "${KATALK_AX_VERSION:-0.1.8}" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${KATALK_AX_BUILD_NUMBER:-8}" "$APP_DIR/Contents/Info.plist"

if [[ -n "${KATALK_AX_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --sign "$KATALK_AX_SIGN_IDENTITY" "$APP_DIR"
else
  if SIGN_IDENTITY=$("$ROOT_DIR/scripts/ensure-local-signing-identity.sh" 2>/dev/null); then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
  else
    codesign --force --deep --sign - "$APP_DIR"
  fi
fi

echo "$APP_DIR"
