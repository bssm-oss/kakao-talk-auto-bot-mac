# katalk-ax

`katalk-ax` is a macOS command line tool that controls the real `KakaoTalk.app` through the macOS Accessibility API. It is designed for local-only automation where reliability and mis-send prevention matter more than speed.

## What it does

- Checks Accessibility permission for the actual process running the tool.
- Finds, launches, and activates `KakaoTalk.app`.
- Inspects KakaoTalk’s Accessibility tree for debugging.
- Lists accessible chat candidates and stores a local chat registry.
- Sends a message to an exactly matched chat, or blocks the send when the result is ambiguous.
- Provides a native AppKit menu bar app that reuses the shared core service for status, chat loading, dry-runs, and sends.

## How it works

`katalk-ax` uses documented macOS APIs only:

- `AXUIElementCreateApplication`
- `AXUIElementCopyAttributeValue`
- `AXUIElementSetAttributeValue`
- `AXUIElementPerformAction`
- `AXObserverCreate`
- `NSWorkspace` / `NSRunningApplication`
- `NSPasteboard`
- `CGEvent`

It does **not** use:

- Kakao API
- LOCO or any unofficial KakaoTalk protocol
- reverse engineering
- OCR
- screenshots for click targeting
- direct database reads
- network hooking
- fixed screen coordinates

## Safety policy

- Default match mode is `exact`.
- If a chat name is ambiguous, the tool fails closed and returns candidates instead of sending.
- `--dry-run` stops before the actual send.
- `--confirm` asks for a terminal confirmation before sending.
- `--speed slow` and normal pacing help reduce aggressive interaction patterns.

## Requirements

- macOS 14+
- Swift 5.9+ (tested here with Swift 6.2)
- `KakaoTalk.app` installed on the same Mac
- KakaoTalk already logged in and unlocked
- Accessibility permission granted to the exact execution host

## Accessibility permission setup

Accessibility permission is granted **per execution host**. If you run `katalk-ax` from Terminal, iTerm, Warp, VS Code integrated terminal, Cursor, or another wrapper app, that host needs permission.

1. Open **System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Enable permission for the process that runs `katalk-ax`
4. Re-run `katalk-ax status --prompt` if you want macOS to show the permission prompt flow

If permission is missing, `katalk-ax` exits with code `2`.

## Quick setup

For a local first-run setup:

```bash
chmod +x scripts/quick-setup.sh
scripts/quick-setup.sh
```

That script:

- builds the CLI, MCP server, and menu bar app targets
- creates `~/.katalk-ax/ai-providers.json` from the sample file if needed
- opens the macOS Accessibility settings pane
- prints the next local verification steps

## Build

```bash
swift build
```

Build the native menu bar app target too:

```bash
swift build --product katalk-ax-menu-bar
```

Build the MCP server target too:

```bash
swift build --product katalk-ax-mcp
```

Release build:

```bash
swift build -c release
```

## Run

Show status:

```bash
swift run katalk-ax status
swift run katalk-ax status --json
```

Launch the native AppKit menu bar app:

```bash
swift run katalk-ax-menu-bar
```

The menu bar app uses a left-click popover for the main workflow and a right-click utility menu for refresh, settings, and quit. It calls `KTalkAXService` directly instead of shelling out to the CLI.

Run the MCP server over stdio:

```bash
swift run katalk-ax-mcp
```

Inspect a KakaoTalk window:

```bash
swift run katalk-ax inspect --depth 5 --show-path --show-frame --show-flags
swift run katalk-ax inspect --window 0 --depth 6 --show-actions --show-attributes --row-summary --json
```

List chat candidates:

```bash
swift run katalk-ax chats --limit 30
swift run katalk-ax chats --limit 30 --json
```

Dry-run a send:

```bash
swift run katalk-ax send --chat "홍길동" --message "테스트 메시지" --dry-run
```

Real send with confirmation:

```bash
swift run katalk-ax send --chat "홍길동" --message "안녕하세요\n두 줄 메시지" --confirm --trace-ax
```

## Native menu bar app

The `katalk-ax-menu-bar` executable is a native AppKit status item app built on the same `KTalkAXCore` package as the CLI.

It includes:

- `NSStatusItem` menu bar presence with a utility right-click menu
- a main popover for automation status, visible chat loading, optional AI draft/rewrite assist, message compose, dry-run, and send
- inline feedback for KakaoTalk availability, permission, AI provider readiness, and send results
- a settings window for menu bar defaults such as match mode, speed, post-send window behavior, and default AI provider selection

The menu bar app keeps the same safety posture as the CLI: it uses the shared `KTalkAXService`, respects ambiguity blocking, and clearly separates dry-run from real send.

AI drafting in the menu bar app reuses the shared provider layer under `Sources/KTalkAX/AI/`. Providers are loaded from `~/.katalk-ax/ai-providers.json` or the supported `GEMINI_API_KEY` / `OPENAI_API_KEY` environment variables. If no provider is configured, the popover stays usable and shows inline setup guidance instead of failing.

## AI setup

The project keeps AI optional. KakaoTalk automation works without any AI provider configured.

### Option A: environment variables

Gemini:

```bash
export GEMINI_API_KEY="your-key"
export GEMINI_MODEL="gemini-1.5-flash"
```

OpenAI-compatible:

```bash
export OPENAI_API_KEY="your-token"
export OPENAI_MODEL="gpt-4.1-mini"
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

### Option B: local config file

Create `~/.katalk-ax/ai-providers.json`:

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

A ready-to-edit sample file is also included at `packaging/examples/ai-providers.sample.json`.

Notes:

- The current implementation supports documented token-based provider access.
- Codex-style product OAuth is not hard-coded into the app because public embeddable OAuth endpoints are not documented as a stable third-party integration surface.
- The menu bar app can still use OpenAI-compatible bearer tokens and Gemini keys through the shared AI layer.

## CLI commands

### `status`

Reports:

- Accessibility trust state
- KakaoTalk running state
- active window count
- login / lock estimate
- cache and registry file paths

Options:

- `--json`
- `--prompt`

### `inspect`

Dumps the Accessibility tree for a KakaoTalk window.

Options:

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

Each node can include role, title, value, description, subrole, frame, path, sibling index, enabled/focused/selected/editable flags, actions, and attribute names.

### `chats`

Prints visible chat candidates that can be reached from the current KakaoTalk UI and refreshes the local registry.

Options:

- `--limit <n>`
- `--json`
- `--refresh-cache`
- `--no-cache`

### `send`

Required:

- `--message "<text>"`
- one of `--chat "<chat name>"` or `--chat-id "<synthetic id>"`

Options:

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

When `--keep-window` is omitted, `katalk-ax` attempts to close the opened chat window after a dry-run or verified send. When it is present, the chat window stays open.

## Cache and registry

- AX path cache: `~/.katalk-ax/ax-cache.json`
- chat registry: `~/.katalk-ax/chat-registry.json`

The path cache stores the most recent successful route to the search field, result list, compose field, and send button. If the stored path no longer validates, the tool falls back to a fresh traversal. The chat registry stores synthetic chat IDs, normalized titles, first/last seen times, and matched text hints.

## Exit codes

- `0` success
- `1` generic error
- `2` Accessibility permission denied
- `3` KakaoTalk not available
- `4` chat not found
- `5` ambiguous chat
- `6` compose field not found
- `7` send failed
- `8` verification failed
- `9` invalid arguments

## Common errors and fixes

### Accessibility permission denied

Grant permission to the exact host process that launches `katalk-ax`.

### KakaoTalk not available

Install `KakaoTalk.app` in `/Applications` or ensure it is already running and visible through `NSWorkspace`.

### Login required / app locked

Open KakaoTalk manually, verify it is logged in, and unlock any lock screen before running the tool.

### Ambiguous chat

Use `chats --json` to inspect candidates, then retry with a more specific chat name or a known `--chat-id`.

### Compose field not found

Run `inspect --show-path --show-frame --show-flags --debug-layout` to capture the current AX tree and compare the lower-half editable controls.

## Privacy and security notes

- The tool runs locally and stores only a small cache and chat registry on disk.
- It does not read KakaoTalk databases or intercept network traffic.
- It can still trigger sends in the real KakaoTalk UI, so use `--dry-run` and `--confirm` for high-risk cases.
- Keep test messages and screenshots free of personal data before sharing logs publicly.

## Folder structure

```text
Sources/KTalkAX/
  CLI/
  Core/
  AX/
  App/
  Input/
  AI/
Sources/KTalkAXMenuBarApp/
Sources/KTalkAXMenuBar/
Sources/KTalkAXMCP/
packaging/macos/
Formula/
Casks/
scripts/
Tests/KTalkAXTests/
Tests/KTalkAXMenuBarTests/
.github/workflows/
docs/changes/
```

## Architecture overview

- `CLI`: argument parsing and command dispatch
- `KTalkAXMenuBarApp`: native AppKit controllers, status item, popover, and settings window
- `KTalkAXMenuBar`: thin executable entry point for the menu bar app
- `KTalkAXMCP`: stdio MCP server over the shared core service
- `Core`: errors, logging, output rendering, timeout helpers, normalization, scoring
- `AX`: raw Accessibility wrappers, traversal, inspection, action helpers
- `App`: KakaoTalk-specific process, window, search, compose, send, recovery, cache, registry logic
- `AI`: optional provider abstraction and HTTP integrations for AI drafting
- `Input`: keyboard, mouse, and pasteboard fallbacks

## Development principles

- fail closed on ambiguity
- prefer semantic AX interactions over synthetic input
- use synthetic keyboard and mouse only as fallbacks
- keep tracing on `stderr` and primary results on `stdout`
- keep docs and tests aligned with actual behavior

## Testing

Run unit tests:

```bash
swift test
```

Run a manual smoke check:

```bash
swift run katalk-ax status --json
swift run katalk-ax inspect --depth 3 --show-path
swift run katalk-ax chats --limit 10
swift run katalk-ax send --chat "테스트" --message "smoke" --dry-run
```

## Manual test checklist

- [ ] 1:1 chat exact match send
- [ ] group chat exact match send
- [ ] ambiguous duplicate-ish chat name blocks send
- [ ] smart match handles spacing or punctuation differences
- [ ] multiline message send
- [ ] Korean message send
- [ ] dry-run stops before send
- [ ] confirm rejection prevents send
- [ ] KakaoTalk launches when initially not running
- [ ] locked KakaoTalk returns a clear error
- [ ] corrupted cache recovers with `--refresh-cache`
- [ ] inspect output is useful for debugging

## CI

The repository includes:

- `swift.yml` for build/test on `push` and `pull_request`
- `release.yml` for tagged builds that produce a CLI archive and a DMG

Local release helpers:

```bash
scripts/build-menu-bar-app.sh release
scripts/create-dmg.sh dist/katalk-ax.app dist/katalk-ax.dmg
```

The release workflow is intentionally unsigned by default. If you add Developer ID signing and notarization secrets later, the DMG flow is ready to extend.

## Homebrew

This repo includes Homebrew tap artifacts at the repository root:

- `Formula/katalk-ax.rb` for the CLI and MCP binaries from the repository source
- `Casks/katalk-ax-menu-bar.rb` for the latest DMG-installed AppKit app release

Recommended install flow:

```bash
brew tap <your-org>/<your-tap>
brew install --HEAD katalk-ax
brew install --cask katalk-ax-menu-bar
```

Notes:

- The formula is concrete and source-builds the CLI and MCP binaries from the repository.
- The cask points at the latest GitHub release DMG.
- This repository is release-ready for that cask path, but the actual GitHub release publication is an external final step.
- If you later want a stable versioned formula, publish tagged archives and replace the `head` formula with a tagged `url` + `sha256` formula in your tap.

## Known limitations

- KakaoTalk’s Accessibility tree can change between versions.
- Some controls may not expose writable AX values, which forces pasteboard or keyboard fallback.
- Post-send verification is conservative and may fail closed when transcript evidence is incomplete.
- The tool cannot grant Accessibility permission on the user’s behalf.

## References

- Apple Accessibility trust check: <https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions>
- Apple AX root creation: <https://developer.apple.com/documentation/applicationservices/1459374-axuielementcreateapplication>
- Apple AX attribute reads: <https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue>
- Apple AX attribute writes: <https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue>
- Apple AX actions: <https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction>
- Apple AX observer API: <https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate>
- Apple NSWorkspace / NSRunningApplication docs
- Apple NSPasteboard docs
- Apple CGEvent docs
- AXSwift: <https://github.com/tmandry/AXSwift>
- DFAXUIElement: <https://github.com/DevilFinger/DFAXUIElement>
