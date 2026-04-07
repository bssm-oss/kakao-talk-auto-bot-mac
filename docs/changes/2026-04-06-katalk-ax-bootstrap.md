# 2026-04-06 katalk-ax 초기 구성

## 배경

작업 시작 시점의 워크스페이스는 사실상 빈 디렉터리였고, Swift 패키지, 문서, 테스트, CI가 없었습니다.

## 목표

macOS 접근성 API로 `KakaoTalk.app`을 자동화하는 첫 번째 `katalk-ax` Swift Package Manager 프로젝트를 구성합니다.

## 변경 내용

- `status`, `inspect`, `chats`, `send` 명령을 포함한 새 Swift 패키지 추가
- AX 래퍼, 순회기, 인스펙터, KakaoTalk 실행/검색/입력/전송/복구 로직 추가
- `~/.katalk-ax/` 아래 캐시와 채팅 레지스트리 저장 구조 추가
- 정규화, 점수 계산, 레지스트리/캐시, JSON 인코딩에 대한 테스트 추가
- README, AGENTS, 기본 GitHub Actions 워크플로 추가

## 설계 이유

- AX 계층은 일반화하고 KakaoTalk 전용 휴리스틱은 분리했습니다.
- 기본 매칭을 exact로 두고 ambiguous일 때는 실패시키도록 설계해 오발송을 막았습니다.
- 전송 검증은 증거가 충분하지 않으면 실패하도록 보수적으로 처리했습니다.

## 영향

- 저장소의 첫 빌드/테스트 가능한 코드베이스가 만들어졌습니다.
- 런타임 캐시와 레지스트리 경로가 정해졌습니다.
- 문서화와 CI의 기본 규칙이 생겼습니다.

## 검증

- `swift build`
- `swift test`
- 수동 CLI 스모크 테스트

## 남아 있는 한계

- 실제 KakaoTalk UI 변화에 따라 셀렉터 조정이 필요할 수 있습니다.
- 접근성 권한과 KakaoTalk 로그인 상태는 외부 전제 조건입니다.
