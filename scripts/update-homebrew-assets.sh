#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?version required}"
CLI_ARCHIVE_URL="${2:?cli archive url required}"
CLI_SHA="${3:?cli sha required}"
DMG_URL="${4:?dmg url required}"
DMG_SHA="${5:?dmg sha required}"

python3 - <<PY
from pathlib import Path
root = Path("$ROOT_DIR")
formula = root / "Formula/katalk-ax.rb"
cask = root / "Casks/katalk-ax-menu-bar.rb"

formula.write_text(formula.read_text().replace("__VERSION__", "$VERSION").replace("__CLI_URL__", "$CLI_ARCHIVE_URL").replace("__CLI_SHA256__", "$CLI_SHA"))
cask.write_text(cask.read_text().replace("__VERSION__", "$VERSION").replace("__DMG_URL__", "$DMG_URL").replace("__DMG_SHA256__", "$DMG_SHA"))
PY
