#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_APP="$HOME/Applications/katalk-ax.app"

mkdir -p "$HOME/Applications"
pkill -x katalk-ax-menu-bar 2>/dev/null || true
sleep 1

"$ROOT_DIR/scripts/build-menu-bar-app.sh" release >/dev/null
/usr/bin/ditto "$ROOT_DIR/dist/katalk-ax.app" "$TARGET_APP"

python3 - <<'PY'
import pathlib, plistlib
app = pathlib.Path.home() / 'Applications' / 'katalk-ax.app'
data = plistlib.loads((app / 'Contents' / 'Info.plist').read_bytes())
print(f"Installed {app}")
print(f"Version: {data.get('CFBundleShortVersionString')} ({data.get('CFBundleVersion')})")
PY
