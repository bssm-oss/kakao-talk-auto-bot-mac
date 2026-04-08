#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$HOME/.katalk-ax"
AI_CONFIG="$CONFIG_DIR/ai-providers.json"
AI_SAMPLE="$ROOT_DIR/packaging/examples/ai-providers.sample.json"

mkdir -p "$CONFIG_DIR"

echo "[1/5] CLI, MCP 서버, 메뉴 막대 앱을 빌드하는 중..."
swift build --package-path "$ROOT_DIR"
swift build --package-path "$ROOT_DIR" --product katalk-ax-mcp
swift build --package-path "$ROOT_DIR" --product katalk-ax-menu-bar
"$ROOT_DIR/scripts/build-cli-app.sh" release

echo "[2/5] 설정 디렉터리를 준비하는 중: $CONFIG_DIR"
if [[ ! -f "$AI_CONFIG" ]]; then
  cp "$AI_SAMPLE" "$AI_CONFIG"
  echo "AI 제공자 샘플 설정 파일을 만들었습니다: $AI_CONFIG"
else
  echo "AI 제공자 설정 파일이 이미 있습니다: $AI_CONFIG"
fi

echo "[3/5] 접근성 설정을 여는 중..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true

echo "[4/5] CLI 앱 번들을 접근성 목록에 추가하세요"
echo "  위치: $ROOT_DIR/dist/katalk-ax-cli.app"

echo "[5/5] 다음 단계"
cat <<EOF
- 접근성 권한 설정:
  1. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용
  2. 다음 중 하나를 추가:
     - 터미널 앱 (Terminal.app, iTerm, Warp 등)
     - 또는: $ROOT_DIR/dist/katalk-ax-cli.app
  3. 권한 토글 켜기
- AI 초안 기능을 쓰려면 $AI_CONFIG 파일을 검토하고 수정하세요.
- 실행 (앱 번들): open $ROOT_DIR/dist/katalk-ax-cli.app
- 실행 (직접): swift run katalk-ax status --json
- 간단 전송 CLI: swift run kabot --room "허동운" --message "안녕"
- 실행: swift run katalk-ax-menu-bar
- 실행: swift run katalk-ax-mcp
- 로컬 앱 설치: $ROOT_DIR/scripts/install-local-app.sh
- 권한 복구: $ROOT_DIR/scripts/repair-accessibility.sh
- 진단: $ROOT_DIR/scripts/check-accessibility.sh
EOF
