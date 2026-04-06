# 2026-04-06 shared core, MCP, and release distribution layer

## Background

The project moved beyond a single CLI into a shared-core product with a native menu bar app requirement, MCP access, and easier distribution.

## Goal

Keep one reusable automation core while adding additional access surfaces and practical release distribution paths.

## What changed

- Split the Swift package into `KTalkAXCore`, `katalk-ax`, `katalk-ax-menu-bar`, and `katalk-ax-mcp`
- Added a public `KTalkAXService` façade over the existing automation graph
- Added a minimal MCP stdio server with tools for status, chats, inspect, and send
- Added an AI provider abstraction with Gemini and OpenAI-compatible HTTP providers plus shared config discovery
- Added scripts for menu bar app bundling and DMG creation
- Added Homebrew tap-root formula/cask entries and a release workflow

## Design reasons

- The menu bar app and MCP layer should reuse the same automation service instead of shelling out to the CLI.
- AI is optional and sits above the automation core so KakaoTalk automation remains deterministic.
- DMG and Homebrew flows are separated because the GUI app and CLI are different distribution shapes.

## Verification

- `swift build`
- `swift build --product katalk-ax-menu-bar`
- `swift build --product katalk-ax-mcp`
- MCP initialize + tools/list smoke test

## Remaining limits

- Published release artifacts currently target Apple Silicon (arm64) only.
- The release workflow currently builds unsigned assets; signing/notarization secrets and steps can be layered on when available.
