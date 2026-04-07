# 2026-04-06 메뉴 막대 아이콘 개선

## 배경

기존 네이티브 AppKit 메뉴 막대 앱은 일반적인 SF Symbol을 그대로 사용했고, 패키징된 `.app`나 DMG에는 실제 번들 아이콘이 없었습니다.

## 목표

현재 SwiftPM + AppKit + 셸 스크립트 기반 패키징 흐름과 호환되면서도 더 자연스러운 네이티브 아이콘 경험을 제공합니다.

## 변경 내용

- 메뉴 막대 상태 아이콘을 단순 SF Symbol 대신 AppKit으로 직접 그린 대화 말풍선 계열 아이콘으로 교체
- idle / busy / warning / error / ready 상태를 일관되게 표현하는 아이콘 해석기 추가
- 바이너리 자산을 직접 넣지 않고, Swift 스크립트로 전체 macOS 아이콘 세트를 생성하도록 변경
- `scripts/build-menu-bar-app.sh`가 `katalk-ax.icns`를 생성해 `katalk-ax.app`에 번들하도록 수정
- `packaging/macos/Info.plist`에 번들 아이콘 정보 추가

## 설계 이유

- 메뉴 막대 아이콘이 앱의 일부처럼 느껴지도록 시각 정체성을 일관되게 만들었습니다.
- 아이콘을 코드로 생성하면 저장소를 텍스트 중심으로 유지하면서 외부 디자인 도구 의존성을 줄일 수 있습니다.
- 기존 릴리즈/DMG 흐름을 유지한 채 아이콘만 개선할 수 있습니다.

## 영향

- 패키징된 `.app`와 DMG에 실제 번들 아이콘이 포함됩니다.
- 메뉴 막대에서도 더 일관된 AppKit 스타일 아이콘을 사용합니다.

## 검증

- `swift build`
- `swift test`
- `scripts/build-menu-bar-app.sh release`
- `scripts/create-dmg.sh dist/katalk-ax.app dist/katalk-ax.dmg`

## 남아 있는 한계

- 생성형 아이콘이므로 향후 미세한 미관 조정은 `scripts/generate-app-iconset.swift`에서 해야 합니다.
