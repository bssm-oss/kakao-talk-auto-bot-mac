#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/${CONFIGURATION}"
APP_NAME="katalk-ax.app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME"
EXECUTABLE_NAME="katalk-ax-menu-bar"

swift build -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/packaging/macos/Info.plist" "$APP_DIR/Contents/Info.plist"

plutil -replace CFBundleShortVersionString -string "${KATALK_AX_VERSION:-0.1.0}" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${KATALK_AX_BUILD_NUMBER:-1}" "$APP_DIR/Contents/Info.plist"

echo "$APP_DIR"
