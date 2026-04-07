# katalk-ax

`katalk-ax`는 macOS 접근성 API로 실제 `KakaoTalk.app`을 직접 조작하는 도구입니다. 로컬 환경에서 특정 채팅방을 찾고, 메시지를 입력하고, 안전하게 드라이런/전송까지 수행할 수 있도록 설계되었습니다.

## 무엇을 할 수 있나요?

- 현재 실행 중인 프로세스의 접근성 권한 상태를 확인합니다.
- `KakaoTalk.app`을 찾고, 실행하고, 활성화합니다.
- KakaoTalk의 접근성 트리를 덤프해서 디버깅할 수 있습니다.
- 보이는 채팅방 목록을 읽고 로컬 채팅 레지스트리를 갱신합니다.
- 특정 채팅방에 특정 메시지를 보내거나, 드라이런으로 전송 직전 흐름만 검증합니다.
- 같은 공유 코어를 사용하는 네이티브 AppKit 메뉴 막대 앱과 MCP 서버를 제공합니다.

## 동작 방식

`katalk-ax`는 공식 macOS API만 사용합니다.

- `AXUIElementCreateApplication`
- `AXUIElementCopyAttributeValue`
- `AXUIElementSetAttributeValue`
- `AXUIElementPerformAction`
- `AXObserverCreate`
- `NSWorkspace` / `NSRunningApplication`
- `NSPasteboard`
- `CGEvent`

다음 방식은 사용하지 않습니다.

- Kakao API
- LOCO 같은 비공식 프로토콜
- 리버스 엔지니어링
- OCR
- 스크린샷 좌표 클릭
- DB 직접 읽기
- 네트워크 후킹
- 고정 좌표 자동화

## 안전 정책

- 기본 매칭 방식은 `exact`입니다.
- 채팅방 이름이 모호하면 전송하지 않고 후보만 보여줍니다.
- `--dry-run`은 실제 전송 전에 중단합니다.
- `--confirm`은 전송 전에 터미널 확인을 받습니다.
- `--speed slow`와 기본 지연은 과도한 자동화를 줄이기 위한 안전 장치입니다.

## 요구 사항

- Apple Silicon(arm64) 기반 macOS 14+
- Swift 5.9+ (현재 환경에서는 Swift 6.2로 검증)
- 같은 Mac에 설치된 `KakaoTalk.app`
- 로그인 및 잠금 해제가 완료된 KakaoTalk
- 실제 실행 주체에 부여된 접근성 권한

## 접근성 권한 설정

접근성 권한은 **실행 주체별**로 필요합니다. 다음 두 가지 방법 중 하나를 선택하세요.

### 방법 1: 앱 번들 사용 (권장)

앱 번들로 빌드하면 시스템이 권한 요청을 더 잘 감지합니다.

```bash
# CLI 앱 빌드
scripts/build-cli-app.sh

# 결과물: dist/katalk-ax-cli.app
```

1. **시스템 설정** 열기
2. **개인정보 보호 및 보안 > 손쉬운 사용**으로 이동
3. `dist/katalk-ax-cli.app`를 목록에 추가
4. 권한 토글 켜기
5. 앱 실행:

```bash
open dist/katalk-ax-cli.app
# 또는 직접 실행
./dist/katalk-ax-cli.app/Contents/MacOS/katalk-ax status
```

### 방법 2: 터미널 앱에 권한 부여

`swift run`으로 직접 실행하는 경우, **터미널 앱 자체**에 권한이 필요합니다.

1. **시스템 설정** 열기
2. **개인정보 보호 및 보안 > 손쉬운 사용**으로 이동
3. 사용하는 터미널 앱에 권한 부여 (Terminal.app, iTerm, Warp, Cursor 터미널 등)
4. 필요하면 `katalk-ax status --prompt`로 권한 요청 흐름 다시 실행

권한이 없으면 `katalk-ax`는 종료 코드 `2`로 끝납니다.

### 문제 해결

권한이 감지되지 않는 경우:

```bash
# 진단 스크립트 실행
scripts/check-accessibility.sh

# 일반적 해결 방법:
# 1. 기존 항목을 접근성 목록에서 제거
# 2. 앱 번들을 다시 추가
# 3. 터미널 재시작
# 4. katalk-ax status --prompt 실행
```

## 빠른 시작

```bash
chmod +x scripts/quick-setup.sh
scripts/quick-setup.sh
```

이 스크립트는 다음을 수행합니다.

- CLI, MCP 서버, 메뉴 막대 앱 빌드
- 필요하면 `~/.katalk-ax/ai-providers.json` 생성
- 접근성 설정 창 열기
- 다음 실행 절차 출력

로컬 설치본은 기본적으로 강제 ad-hoc 서명 없이 빌드합니다. 그래야 `~/Applications/katalk-ax.app`를 같은 경로로 덮어쓸 때 접근성 권한이 더 안정적으로 유지됩니다. 별도 서명이 필요하면 `KATALK_AX_SIGN_IDENTITY` 환경 변수를 지정해 명시적으로 서명할 수 있습니다.

## 빌드

```bash
swift build
```

메뉴 막대 앱 타깃 빌드:

```bash
swift build --product katalk-ax-menu-bar
```

MCP 서버 타깃 빌드:

```bash
swift build --product katalk-ax-mcp
```

릴리즈 빌드:

```bash
swift build -c release
```

## 실행

상태 확인:

```bash
swift run katalk-ax status
swift run katalk-ax status --json
```

네이티브 AppKit 메뉴 막대 앱 실행:

```bash
swift run katalk-ax-menu-bar
```

이 메뉴 막대 앱은 좌클릭 팝오버와 우클릭 유틸리티 메뉴를 사용하며, CLI를 호출하지 않고 `KTalkAXService`를 직접 사용합니다. 팝오버를 열면 설정 요약이 아니라 **채팅방 이름 입력 → 메시지 입력 → 드라이런/전송** 흐름이 바로 보이도록 구성되어 있습니다.

MCP 서버 실행:

```bash
swift run katalk-ax-mcp
```

접근성 트리 확인:

```bash
swift run katalk-ax inspect --depth 5 --show-path --show-frame --show-flags
swift run katalk-ax inspect --window 0 --depth 6 --show-actions --show-attributes --row-summary --json
```

채팅방 목록 확인:

```bash
swift run katalk-ax chats --limit 30
swift run katalk-ax chats --limit 30 --json
```

특정 채팅방에 특정 메시지 드라이런:

```bash
swift run katalk-ax send --chat "홍길동" --message "테스트 메시지" --dry-run
```

실제 전송(확인 포함):

```bash
swift run katalk-ax send --chat "홍길동" --message "안녕하세요
두 줄 메시지" --confirm --trace-ax
```

## 네이티브 메뉴 막대 앱

`katalk-ax-menu-bar`는 CLI와 같은 `KTalkAXCore`를 재사용하는 AppKit 기반 상태 메뉴 앱입니다.

포함된 기능:

- `NSStatusItem` 기반 메뉴 막대 아이콘
- 채팅방 이름 입력, 메시지 입력, 드라이런, 전송을 바로 수행하는 메인 팝오버
- 필요할 때 참고할 수 있는 보이는 채팅방 목록과 간단한 상태 피드백
- 권한 상태, KakaoTalk 상태, AI 설정 여부에 대한 인라인 피드백
- 매칭 방식, 속도, 전송 후 창 유지 여부, 기본 AI 제공자를 설정하는 별도 설정 창

이제 패키징된 `.app`는 `scripts/build-menu-bar-app.sh` 실행 중 `.icns`를 코드로 생성해서 번들에 포함합니다. 따라서 Finder/DMG에서도 실제 앱 아이콘이 보입니다.

## AI 설정

AI 기능은 선택 사항입니다. KakaoTalk 자동화 자체는 AI 없이도 동작합니다.

### 방법 1: 환경 변수

Gemini:

```bash
export GEMINI_API_KEY="your-key"
export GEMINI_MODEL="gemini-1.5-flash"
```

OpenAI 호환 API:

```bash
export OPENAI_API_KEY="your-token"
export OPENAI_MODEL="gpt-4.1-mini"
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

### 방법 2: 로컬 설정 파일

`~/.katalk-ax/ai-providers.json` 파일 생성:

```json
{
  "providers": [
    {
      "provider": "gemini",
      "model": "gemini-1.5-flash",
      "apiKey": "your-key"
    },
    {
      "provider": "openai-compatible",
      "model": "gpt-4.1-mini",
      "baseURL": "https://api.openai.com/v1",
      "authToken": "your-token"
    }
  ]
}
```

샘플 파일은 `packaging/examples/ai-providers.sample.json`에도 들어 있습니다.

참고:

- 현재 구현은 문서화된 토큰 기반 제공자 연결만 지원합니다.
- Codex 스타일 제품 OAuth는 공개된 안정적인 임베디드 연동 표면이 없어 앱에 하드코딩하지 않았습니다.
- 대신 Gemini 키나 OpenAI 호환 토큰을 같은 공유 AI 계층으로 사용할 수 있습니다.

## CLI 명령어

### `status`

다음을 확인합니다.

- 접근성 권한 상태
- KakaoTalk 실행 상태
- 활성 창 개수
- 로그인/잠금 추정 상태
- 캐시/레지스트리 경로

옵션:

- `--json`
- `--prompt`

### `inspect`

KakaoTalk 창의 접근성 트리를 덤프합니다.

옵션:

- `--window <index>`
- `--depth <n>`
- `--show-attributes`
- `--show-actions`
- `--show-path`
- `--show-frame`
- `--show-index`
- `--show-flags`
- `--debug-layout`
- `--row-summary`
- `--json`

### `chats`

현재 보이는 채팅방 후보를 읽고 로컬 레지스트리를 갱신합니다.

옵션:

- `--limit <n>`
- `--json`
- `--refresh-cache`
- `--no-cache`

### `send`

특정 채팅방에 특정 메시지를 보냅니다. `--dry-run`을 사용하면 실제 전송 없이 열기/입력 가능 여부까지만 검증합니다.

필수:

- `--message "<메시지>"`
- `--chat "<채팅방 이름>"` 또는 `--chat-id "<synthetic id>"`

옵션:

- `--chat-id "<synthetic id>"`
- `--dry-run`
- `--confirm`
- `--trace-ax`
- `--keep-window`
- `--deep-recovery`
- `--match exact|smart|fuzzy`
- `--speed slow|normal|fast`
- `--json`
- `--refresh-cache`
- `--no-cache`

## MCP

`katalk-ax-mcp`는 stdio 기반 MCP 서버입니다. 공유 코어를 그대로 재사용하며 다음 도구를 제공합니다.

- `katalk_status`
- `katalk_chats`
- `katalk_inspect`
- `katalk_send`

## 폴더 구조

```text
Sources/KTalkAX/
  CLI/
  Core/
  AX/
  App/
  Input/
  AI/
Sources/KTalkAXCLI/
Sources/KTalkAXMenuBarApp/
Sources/KTalkAXMenuBar/
Sources/KTalkAXMCP/
packaging/macos/
packaging/examples/
Formula/
Casks/
scripts/
Tests/KTalkAXTests/
Tests/KTalkAXMenuBarTests/
.github/workflows/
docs/changes/
```

## 배포

로컬 앱 번들 생성:

```bash
scripts/build-menu-bar-app.sh release
```

DMG 생성:

```bash
scripts/create-dmg.sh dist/katalk-ax.app dist/katalk-ax.dmg
```

GitHub Actions:

- `swift.yml`: 빌드/테스트
- `release.yml`: DMG와 CLI 아카이브 릴리즈

현재 공개 릴리즈 자산은 Apple Silicon 전용입니다.

## Homebrew 설치

이 저장소는 Homebrew 탭 루트 구조를 사용합니다.

- `Formula/katalk-ax.rb`
- `Casks/katalk-ax-menu-bar.rb`

설치 예시:

```bash
brew tap bssm-oss/kakao-talk-auto-bot-mac https://github.com/bssm-oss/kakao-talk-auto-bot-mac
brew install bssm-oss/kakao-talk-auto-bot-mac/katalk-ax
brew install --cask bssm-oss/kakao-talk-auto-bot-mac/katalk-ax-menu-bar
```

참고:

- 저장소 이름이 `homebrew-<tap>` 형식이 아니므로 커스텀 tap URL이 필요합니다.
- formula는 릴리즈된 CLI/MCP 아카이브를 직접 설치합니다.
- cask는 최신 GitHub 릴리즈 DMG를 사용합니다.
- 공개된 DMG와 Homebrew 설치 경로는 현재 Apple Silicon 전용입니다.

## 수동 테스트 체크리스트

- [ ] 1:1 채팅방 exact match 전송
- [ ] 그룹 채팅 exact match 전송
- [ ] 비슷한 이름의 채팅방이 여러 개일 때 ambiguous 차단 확인
- [ ] 공백/특수문자 차이가 있는 채팅방 smart match 확인
- [ ] 여러 줄 메시지 전송
- [ ] 한글 메시지 전송
- [ ] dry-run 동작 확인
- [ ] confirm 거부 시 미전송 확인
- [ ] KakaoTalk 미실행 상태에서 자동 실행 확인
- [ ] KakaoTalk 잠금 상태 오류 확인
- [ ] 캐시 손상 후 `--refresh-cache` 복구 확인
- [ ] inspect 출력 확인

## 알려진 제한 사항

- 공개 릴리즈 자산은 현재 Apple Silicon(arm64) 전용입니다.
- KakaoTalk의 접근성 트리는 버전에 따라 달라질 수 있습니다.
- 일부 컨트롤은 쓰기 가능한 AX 값을 노출하지 않아 pasteboard/keyboard fallback이 필요할 수 있습니다.
- 전송 검증은 보수적으로 동작하며, 증거가 부족하면 실패로 처리합니다.
- 도구가 사용자를 대신해 접근성 권한을 부여할 수는 없습니다.
