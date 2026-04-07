#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/${CONFIGURATION}"
APP_NAME="katalk-ax-cli.app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME"
EXECUTABLE_NAME="katalk-ax"
VERSION="${KATALK_AX_VERSION:-0.1.4}"
BUILD_NUMBER="${KATALK_AX_BUILD_NUMBER:-4}"

mkdir -p "$ROOT_DIR/dist"

echo "Building katalk-ax CLI ($CONFIGURATION)..."
swift build -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/packaging/macos/Info-CLI.plist" "$APP_DIR/Contents/Info.plist"

# Update version info
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

# Sign the app (ad-hoc signing)
if [[ -n "${KATALK_AX_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --sign "$KATALK_AX_SIGN_IDENTITY" "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

echo "Built: $APP_DIR"
echo "To run: open \"$APP_DIR\" or execute \"$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME\""
echo ""
echo "IMPORTANT: Grant Accessibility permission to this app bundle:"
echo "  1. Open System Settings > Privacy & Security > Accessibility"
echo "  2. Add \"$APP_DIR\""
echo "  3. Enable the toggle"
