# 2026-04-06 menu bar AI draft workflow

## Background

The native AppKit menu bar app already handled status checks, visible chat loading, dry runs, and verified sends, while the shared core package already contained reusable AI provider support.

## Goal

Expose a focused AI draft assist flow in the existing menu bar popover without changing the underlying KakaoTalk automation safety model.

## What changed

- Added a small `AIDraftWorkflow` helper in `KTalkAXMenuBarApp` that reuses `AIComposerService` and provider configurations from `Sources/KTalkAX/AI/`
- Added a popover-level AI prompt field plus `AI Draft` and `Rewrite with AI` actions that write back into the existing message compose box
- Added settings support for choosing the default configured AI provider used by the popover workflow
- Added inline feedback when no provider is configured, keeping the manual compose, Dry Run, and Send path available
- Added unit coverage for AI prompt request building and AI provider preference persistence
- Updated the README for the new menu bar AI draft behavior

## Design reasons

- AI stays optional and front-loaded: it only prepares or revises the message draft before the user explicitly chooses Dry Run or Send.
- Provider selection lives in Settings so the main popover stays focused on chat selection, drafting, and send decisions.
- Setup guidance points at the existing shared provider configuration file and environment variables instead of introducing app-specific auth flows.

## Impact

- The menu bar app can now help generate or revise a KakaoTalk draft while preserving the current native AppKit workflow.
- The existing shared AI provider layer is now exercised by both the core package and the native app shell.

## Verification

- `swift build`
- `swift test`
- `swift run katalk-ax status --json`

## Remaining limits

- The menu bar app still does not manage AI credentials directly; users must configure providers through the existing shared file or environment variables.
- AI output is not auto-sent or auto-verified; users must still review the draft and explicitly choose Dry Run or Send.
