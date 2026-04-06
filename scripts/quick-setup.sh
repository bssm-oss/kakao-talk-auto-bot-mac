#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$HOME/.katalk-ax"
AI_CONFIG="$CONFIG_DIR/ai-providers.json"
AI_SAMPLE="$ROOT_DIR/packaging/examples/ai-providers.sample.json"

mkdir -p "$CONFIG_DIR"

echo "[1/4] Building CLI, MCP server, and menu bar app..."
swift build --package-path "$ROOT_DIR"
swift build --package-path "$ROOT_DIR" --product katalk-ax-mcp
swift build --package-path "$ROOT_DIR" --product katalk-ax-menu-bar

echo "[2/4] Preparing config directory at $CONFIG_DIR"
if [[ ! -f "$AI_CONFIG" ]]; then
  cp "$AI_SAMPLE" "$AI_CONFIG"
  echo "Created AI provider sample config at $AI_CONFIG"
else
  echo "AI provider config already exists at $AI_CONFIG"
fi

echo "[3/4] Opening Accessibility settings..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true

echo "[4/4] Next steps"
cat <<EOF
- Grant Accessibility permission to the app or terminal that will run katalk-ax.
- Review and edit $AI_CONFIG if you want AI drafting.
- Run: swift run katalk-ax status --json
- Run: swift run katalk-ax-menu-bar
- Run: swift run katalk-ax-mcp
EOF
