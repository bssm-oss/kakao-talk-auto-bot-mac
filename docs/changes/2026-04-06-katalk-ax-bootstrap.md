# 2026-04-06 katalk-ax bootstrap

## Background

The workspace started as an effectively empty directory with no Swift package, no docs, no tests, and no CI.

## Goal

Create the first full `katalk-ax` Swift Package Manager project that automates `KakaoTalk.app` through macOS Accessibility APIs with a fail-closed send workflow.

## What changed

- Added a new Swift package with the requested command surface: `status`, `inspect`, `chats`, `send`
- Added AX wrappers, traversal, inspector output, KakaoTalk launcher/window/search/compose/send/recovery logic
- Added AX path cache and chat registry persistence under `~/.katalk-ax/`
- Added unit tests for normalizer, scoring, registry/cache persistence, and JSON encoding
- Added README, AGENTS, and a minimal macOS GitHub Actions workflow

## Design reasons

- The AX layer is generic so KakaoTalk-specific heuristics stay isolated.
- Matching defaults to exact and blocks on ambiguity to avoid accidental sends.
- Verification fails closed when the tool cannot observe enough evidence after send.

## Impact

- Introduces the repository’s first buildable/testable codebase.
- Establishes runtime cache and registry file locations.
- Establishes documentation and CI conventions.

## Verification

- `swift build`
- `swift test`
- manual CLI smoke checks documented in the final report

## Remaining limits

- Real KakaoTalk UI drift may require future selector tuning.
- Accessibility permissions and KakaoTalk login state remain external prerequisites.

## Follow-up

- Tune heuristics against additional KakaoTalk UI variants as real-world traces are collected.
