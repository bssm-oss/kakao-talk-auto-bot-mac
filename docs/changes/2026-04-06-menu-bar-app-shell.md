# 2026-04-06 menu bar app shell

## Background

The package already had a shared `KTalkAXCore` library and a CLI executable, but no native macOS app shell for a menu-bar-first workflow.

## Goal

Add a buildable AppKit menu bar executable that reuses `KTalkAXService` directly for status, chat loading, dry-run, and verified send operations.

## What changed

- Added a new `katalk-ax-menu-bar` executable target and a `KTalkAXMenuBarApp` AppKit support target in SwiftPM
- Added a native `NSStatusItem` controller with a left-click popover and a right-click utility menu
- Added a main popover workflow with automation status, visible chat list, message compose UI, dry-run/send actions, and inline feedback
- Added a settings window stub with menu bar defaults for match mode, speed, and post-send window behavior
- Added unit tests for compose validation and menu bar preference persistence
- Updated README with build/run guidance for the new native app target

## Design reasons

- The app shell stays thin and reuses the shared core through `KTalkAXService` instead of shelling out to the CLI.
- The main workflow lives in a popover because the status item menu is too constrained for chat selection and compose actions.
- Settings remain separate so the popover can stay focused on quick automation work.

## Impact

- The repository now contains both a CLI and a native AppKit menu bar executable.
- Shared send safety, ambiguity blocking, and verification logic remain centralized in the core package.

## Verification

- `swift build`
- `swift test`
- `swift run katalk-ax status --json`

## Remaining limits

- The menu bar app does not yet persist full window state or recent drafts.
- Real KakaoTalk UI drift can still affect both the CLI and the new app because they share the same Accessibility heuristics.
