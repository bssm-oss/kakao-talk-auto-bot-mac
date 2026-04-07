# 2026-04-08: Accessibility Permission Detection Fix

## 문제

macOS가 접근성 권한을 제대로 감지하지 못함. 사용자가 시스템 설정에서 권한을 부여해도 `AXIsProcessTrustedWithOptions`가 `false`를 반환.

## 원인

1. CLI 실행 파일에 `Info.plist`가 없어서 `NSAccessibilityUsageDescription`이 없음
2. 메뉴 막대 앱의 `Info.plist`에도 `NSAccessibilityUsageDescription`이 누락
3. 원시 실행 파일(raw executable)은 macOS에서 권한 요청 프롬프트를 제대로 표시하지 않음

## 해결

### 1. NSAccessibilityUsageDescription 추가

- `packaging/macos/Info.plist`: 메뉴 막대 앱에 설명 추가
- `packaging/macos/Info-CLI.plist`: CLI용 새 Info.plist 생성

### 2. CLI 앱 번들 빌드 스크립트

- `scripts/build-cli-app.sh`: CLI를 `.app` 번들로 패키징
- Info.plist 포함
- 자동 codesign (ad-hoc)
- 빌드 후 사용자에게 권한 설정 방법 안내 메시지 표시

### 3. 개선된 오류 메시지

- `KTalkAXError.notTrusted`에서 상세한 해결 방법 표시
- 현재 프로세스 정보 로깅 강화 (bundle identifier, path)
- 한국어로 단계별 안내 제공

### 4. 진단 도구

- `scripts/check-accessibility.sh`: 현재 상태 확인 스크립트
- KakaoTalk 실행 상태, 앱 번들 존재 여부, 코드 서명 정보 확인

### 5. 문서 업데이트

- README.md: 접근성 권한 설정 방법을 두 가지 방법으로 분리
  - 방법 1: 앱 번들 사용 (권장)
  - 방법 2: 터미널 앱에 권한 부여
- 문제 해결 섹션 추가
- quick-setup.sh 스크립트 업데이트

## 사용 방법

```bash
# 1. CLI 앱 빌드
scripts/build-cli-app.sh

# 2. 결과물 확인
ls -la dist/katalk-ax-cli.app

# 3. 권한 설정
# 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용
# dist/katalk-ax-cli.app 추가 후 활성화

# 4. 실행
open dist/katalk-ax-cli.app
# 또는
./dist/katalk-ax-cli.app/Contents/MacOS/katalk-ax status

# 5. 진단 (필요시)
scripts/check-accessibility.sh
```

## 영향

- ✅ 접근성 권한 감지 정확도 향상
- ✅ 사용자가 권한 문제를 스스로 진단하고 해결 가능
- ✅ macOS의 공식 앱 번들 구조를 사용하여 시스템 통합 개선
- ✅ 기존 `swift run katalk-ax` 방식도 계속 작동 (터미널 앱에 권한 필요)

## 파일 변경

### 새로 추가된 파일
- `packaging/macos/Info-CLI.plist`
- `scripts/build-cli-app.sh`
- `scripts/check-accessibility.sh`
- `docs/changes/2026-04-08-accessibility-permission-fix.md`

### 수정된 파일
- `packaging/macos/Info.plist` - NSAccessibilityUsageDescription 추가
- `Sources/KTalkAX/App/KakaoTalkLauncher.swift` - 권한 체크 로깅 개선
- `Sources/KTalkAX/Core/Errors.swift` - notTrusted 오류 메시지 개선
- `README.md` - 접근성 권한 설정 문서 업데이트
- `scripts/quick-setup.sh` - CLI 앱 빌드 단계 추가
