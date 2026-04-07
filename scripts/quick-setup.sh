#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$HOME/.katalk-ax"
AI_CONFIG="$CONFIG_DIR/ai-providers.json"
AI_SAMPLE="$ROOT_DIR/packaging/examples/ai-providers.sample.json"

mkdir -p "$CONFIG_DIR"

echo "[1/4] CLI, MCP 서버, 메뉴 막대 앱을 빌드하는 중..."
swift build --package-path "$ROOT_DIR"
swift build --package-path "$ROOT_DIR" --product katalk-ax-mcp
swift build --package-path "$ROOT_DIR" --product katalk-ax-menu-bar

echo "[2/4] 설정 디렉터리를 준비하는 중: $CONFIG_DIR"
if [[ ! -f "$AI_CONFIG" ]]; then
  cp "$AI_SAMPLE" "$AI_CONFIG"
  echo "AI 제공자 샘플 설정 파일을 만들었습니다: $AI_CONFIG"
else
  echo "AI 제공자 설정 파일이 이미 있습니다: $AI_CONFIG"
fi

echo "[3/4] 접근성 설정을 여는 중..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true

echo "[4/4] 다음 단계"
cat <<EOF
- katalk-ax를 실행할 앱 또는 터미널에 접근성 권한을 부여하세요.
- AI 초안 기능을 쓰려면 $AI_CONFIG 파일을 검토하고 수정하세요.
- 실행: swift run katalk-ax status --json
- 실행: swift run katalk-ax-menu-bar
- 실행: swift run katalk-ax-mcp
EOF
