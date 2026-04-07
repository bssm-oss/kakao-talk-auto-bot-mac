# 2026-04-06 공유 코어, MCP, 배포 계층

## 배경

프로젝트가 단일 CLI를 넘어, 공유 코어를 중심으로 메뉴 막대 앱과 MCP 접근 계층, 쉬운 배포 경로까지 갖춘 제품 형태로 확장되었습니다.

## 목표

하나의 재사용 가능한 자동화 코어를 유지하면서 CLI, 메뉴 막대 앱, MCP, 배포 경로를 함께 제공하는 구조를 만듭니다.

## 변경 내용

- Swift 패키지를 `KTalkAXCore`, `katalk-ax`, `katalk-ax-menu-bar`, `katalk-ax-mcp` 구조로 분리
- 기존 자동화 그래프 위에 공개 `KTalkAXService` 파사드 추가
- `status`, `chats`, `inspect`, `send`를 제공하는 최소 MCP stdio 서버 추가
- Gemini와 OpenAI 호환 HTTP 제공자를 포함한 AI 제공자 추상화 추가
- 메뉴 막대 앱 번들 생성, DMG 생성 스크립트 추가
- GitHub 릴리즈 워크플로와 Homebrew Formula/Cask 추가

## 설계 이유

- 메뉴 막대 앱과 MCP는 CLI를 다시 호출하지 않고 같은 자동화 서비스를 재사용해야 합니다.
- AI는 선택 사항이며, 자동화 코어 위에 얹히는 계층으로 두어 결정론적인 전송 흐름을 해치지 않게 했습니다.
- GUI 앱과 CLI는 배포 모양이 다르므로 DMG와 Homebrew 경로를 분리했습니다.

## 검증

- `swift build`
- `swift build --product katalk-ax-menu-bar`
- `swift build --product katalk-ax-mcp`
- MCP initialize / tools/list 스모크 테스트

## 남아 있는 한계

- 공개 릴리즈 자산은 현재 Apple Silicon(arm64) 전용입니다.
- 릴리즈 워크플로는 현재 unsigned 자산을 빌드하며, 서명/노타리제이션은 추후 추가 가능합니다.
