# AGENTS.md

## Project purpose

This repository contains `katalk-ax`, a Swift Package Manager CLI that automates the real `KakaoTalk.app` with macOS Accessibility APIs only.

## Quick start

```bash
swift build
swift test
swift run katalk-ax status --json
```

## Install / run / test commands

- Build: `swift build`
- Release build: `swift build -c release`
- Test: `swift test`
- Status: `swift run katalk-ax status --json`
- Inspect: `swift run katalk-ax inspect --depth 4 --show-path`
- Chat list: `swift run katalk-ax chats --limit 20`
- Dry-run send: `swift run katalk-ax send --chat "테스트" --message "smoke" --dry-run`

## Default work sequence

1. Read `README.md` and this file.
2. Verify the workspace state and build/test commands.
3. Keep changes scoped to the requested behavior.
4. Add or update tests for modified logic.
5. Update docs when behavior changes.
6. Run `swift build` and `swift test`.
7. Run an appropriate manual CLI check.

## Definition of done

- Requested behavior is implemented.
- `swift build` succeeds.
- `swift test` succeeds.
- Relevant manual CLI checks were run.
- README and docs match the code.
- No claims are made without executed evidence.

## Code style principles

- Prefer small, explicit types over clever abstractions.
- Keep AX wrappers generic and KakaoTalk heuristics in `Sources/KTalkAX/App/`.
- Fail closed when matching is ambiguous or verification is weak.
- Keep `stdout` for results and `stderr` for trace output.

## File structure principles

- `CLI/` for parsing and dispatch only.
- `Core/` for shared primitives.
- `AX/` for generic Accessibility wrappers.
- `App/` for KakaoTalk-specific logic.
- `Input/` for fallback input mechanisms.
- `Tests/` for unit tests only; integration-style checks belong in docs/manual procedures.

## Documentation principles

- Update `README.md` for user-visible behavior changes.
- Add a dated note under `docs/changes/` for meaningful implementation work.
- Keep instructions runnable and evidence-based.

## Testing principles

- Test normalizer, scoring, ambiguity handling, registry/cache persistence, and JSON encoding.
- Prefer deterministic unit tests over UI-dependent tests.
- Manual KakaoTalk interaction checks must be documented when automation is impractical.

## Branch / commit / PR rules

- Do not assume Git exists in the workspace.
- If Git is available, use feature/fix/docs/test prefixes.
- Keep commits single-purpose.
- Include build/test/manual verification results in PR descriptions.

## Sensitive paths / caution areas

- `Sources/KTalkAX/AX/` because changes affect every command.
- `Sources/KTalkAX/App/KakaoTalkSender.swift` because send safety and verification live there.
- `~/.katalk-ax/` runtime files should never be committed.

## Before-work checklist

- Confirm Accessibility permission behavior is still correct.
- Confirm KakaoTalk path and process detection assumptions.
- Confirm tests cover changed logic.

## After-work checklist

- Run `swift build`.
- Run `swift test`.
- Run at least one manual CLI command.
- Update docs.

## Never do this

- Do not add OCR, reverse engineering, network hooks, or unofficial protocols.
- Do not replace ambiguity blocking with automatic fuzzy selection.
- Do not claim KakaoTalk send verification succeeded unless the code actually checked evidence.
- Do not commit runtime cache or registry files.
