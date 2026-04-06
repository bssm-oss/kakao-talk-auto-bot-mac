#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${1:-$ROOT_DIR/dist/katalk-ax.app}"
DMG_PATH="${2:-$ROOT_DIR/dist/katalk-ax.dmg}"
STAGING_DIR="$ROOT_DIR/dist/dmg-root"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create -volname "katalk-ax" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "$DMG_PATH"
