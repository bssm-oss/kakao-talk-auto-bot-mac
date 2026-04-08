#!/usr/bin/env bash
set -euo pipefail

APP_PATH="$HOME/Applications/katalk-ax.app"
BUNDLE_ID="org.bssm.katalk-ax"

if [[ ! -d "$APP_PATH" ]]; then
  echo "앱이 설치되어 있지 않습니다: $APP_PATH" >&2
  exit 1
fi

tccutil reset Accessibility "$BUNDLE_ID" || true
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
open "$APP_PATH" || true

cat <<EOF
현재 앱 기준으로 접근성 권한을 다시 요청했습니다.

1. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서
2. katalk-ax 항목이 보이면 켜고,
3. 보이지 않으면 앱을 다시 실행해 추가한 뒤 켜세요.

설정 후 다음 명령으로 확인하세요:
  "$APP_PATH/Contents/MacOS/katalk-ax-menu-bar" --print-accessibility-status
EOF
