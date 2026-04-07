# Accessibility Permission Fix - Implementation Summary

## ✅ Completed: 2026-04-08

### Problem Solved
macOS 접근성 권한이 시스템 설정에서 부여되었음에도 `AXIsProcessTrustedWithOptions`가 `false`를 반환하여 앱이 작동하지 않던 문제를 해결.

### Root Cause
1. 원시 실행 파일(raw executable)에는 `Info.plist`가 없어서 `NSAccessibilityUsageDescription`이 없음
2. macOS는 `Info.plist`가 없는 실행 파일에게 권한 요청 프롬프트를 제대로 표시하지 않음
3. 메뉴 막대 앱에도 이 설명이 누락되어 있었음

### Solution Implemented

#### 1. Created Info.plist Files
- **`packaging/macos/Info-CLI.plist`**: CLI 전용 새 Info.plist
- **`packaging/macos/Info.plist`**: 메뉴 막대 앱에 `NSAccessibilityUsageDescription` 추가

#### 2. Build Scripts
- **`scripts/build-cli-app.sh`**: 
  - CLI를 `.app` 번들로 패키징
  - Info.plist 자동 포함
  - Ad-hoc 코드 서명
  - 사용자에게 설정 안내 메시지 표시

- **`scripts/check-accessibility.sh`**:
  - KakaoTalk 실행 상태 확인
  - 앱 번들 존재 여부 확인
  - 코드 서명 정보 표시
  - 문제 해결 단계 안내

#### 3. Improved Error Messages
- **`Sources/KTalkAX/Core/Errors.swift`**:
  - `notTrusted` 오류에서 상세한 한국어 해결 가이드 제공
  - 3단계 설정 안내
  - `--prompt` 옵션 사용 안내
  - Info.plist 설명 포함

- **`Sources/KTalkAX/App/KakaoTalkLauncher.swift`**:
  - 권한 체크 시 상세 로깅 추가
  - Bundle identifier 및 path 기록

#### 4. Documentation Updates
- **`README.md`**:
  - 접근성 권한 설정 방법을 두 가지로 분리
    - 방법 1: 앱 번들 사용 (권장)
    - 방법 2: 터미널 앱에 권한 부여
  - 문제 해결 섹션 추가
  - 진단 스크립트 사용법 추가

- **`scripts/quick-setup.sh`**:
  - CLI 앱 빌드 단계 추가
  - 권한 설정 안내 메시지 개선

### How to Use

#### Quick Setup (Recommended)
```bash
chmod +x scripts/quick-setup.sh
scripts/quick-setup.sh
```

#### Manual Setup
```bash
# 1. Build CLI app bundle
scripts/build-cli-app.sh

# 2. Grant Accessibility Permission
# Open: System Settings > Privacy & Security > Accessibility
# Add: dist/katalk-ax-cli.app
# Enable the toggle

# 3. Run
open dist/katalk-ax-cli.app
# Or directly:
./dist/katalk-ax-cli.app/Contents/MacOS/katalk-ax status

# 4. Diagnose (if needed)
scripts/check-accessibility.sh
```

### Verification Results

✅ `swift build` - Success
✅ `swift test` - Success  
✅ CLI app bundle built and signed
✅ Info.plist contains `NSAccessibilityUsageDescription`
✅ Error messages provide Korean troubleshooting guide
✅ Diagnostic script created and tested
✅ README updated with comprehensive setup instructions
✅ Changes pushed to `main` branch

### Files Changed

**New Files (4):**
- `packaging/macos/Info-CLI.plist`
- `scripts/build-cli-app.sh`
- `scripts/check-accessibility.sh`
- `docs/changes/2026-04-08-accessibility-permission-fix.md`

**Modified Files (5):**
- `packaging/macos/Info.plist` - Added NSAccessibilityUsageDescription
- `Sources/KTalkAX/App/KakaoTalkLauncher.swift` - Enhanced permission logging
- `Sources/KTalkAX/Core/Errors.swift` - Improved error messages
- `README.md` - Comprehensive accessibility setup documentation
- `scripts/quick-setup.sh` - Added CLI app bundle build step

### Git History
- **Commit**: `9b5f162`
- **Branch**: `main`
- **Status**: Pushed to `origin/main`
- **Remote**: https://github.com/bssm-oss/kakao-talk-auto-bot-mac.git

### Next Steps for Users

1. **권한이 이미 부여된 경우**:
   ```bash
   # 앱 번들로 다시 빌드
   scripts/build-cli-app.sh
   
   # 시스템 설정에서 제거 후 다시 추가
   # System Settings > Privacy & Security > Accessibility
   # Remove old entry, add dist/katalk-ax-cli.app
   
   # 재시작 후 테스트
   ./dist/katalk-ax-cli.app/Contents/MacOS/katalk-ax status
   ```

2. **권한이 아직 부여되지 않은 경우**:
   ```bash
   # 빠른 설정 스크립트 실행
   scripts/quick-setup.sh
   
   # 표시되는 시스템 설정 창에서 권한 부여
   # 터미널 앱 또는 dist/katalk-ax-cli.app 선택
   ```

3. **문제가 지속되는 경우**:
   ```bash
   # 진단 스크립트 실행
   scripts/check-accessibility.sh
   
   # 출력된 단계별 해결 방법 따르기
   ```

### Technical Notes

- **Why App Bundle?**: macOS는 앱 번들(.app)을 더 잘 인식하고, Info.plist의 `NSAccessibilityUsageDescription`을 사용하여 권한 요청 대화상자에 설명을 표시
- **Ad-hoc Signing**: `codesign --sign -`로 서명하여 로컬 실행 가능 (배포 시에는 개발자 인증서 사용 가능)
- **Backward Compatibility**: 기존 `swift run katalk-ax` 방식도 계속 작동 (단, 터미널 앱에 권한 필요)

### Testing Checklist

- [x] Build succeeds without errors
- [x] Tests pass
- [x] CLI app bundle builds correctly
- [x] Info.plist contains NSAccessibilityUsageDescription
- [x] App bundle is properly code-signed
- [x] Error messages display Korean troubleshooting guide
- [x] Diagnostic script runs correctly
- [x] README documentation is accurate and complete
- [x] Quick-setup script includes all build steps

---

**Status**: ✅ COMPLETE - Ready for user testing
**Date**: 2026-04-08
**Branch**: main (pushed to origin)
