# TokenIsland

> A macOS notch panel that shows **live AI coding agent status** and **token usage** for **Claude Code** and **Codex CLI**, distributed via GitHub Releases.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE) ![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

English | [简体中文](./README_ZH.md)

---

## What it is

TokenIsland lives in your MacBook's notch area and shows two things in real time:

1. **Active AI coding agent state** — sessions, tool calls, permission requests, idle/running/waiting — for Claude Code and Codex.
2. **Today's token usage** — billable tokens for each provider, parsed directly from local session logs. No remote API calls.

It is heavily inspired by [CodeIsland](https://github.com/wxtsky/CodeIsland) (notch UI + IPC architecture) and [TokenUsed](https://github.com/uniStark/token-used) (local jsonl parsing).
TokenIsland is the **two-CLI** distillation: Claude + Codex only, no App Store, no developer-program signing requirement.

## Status

🚧 **Pre-alpha.** Notch panel renders, jsonl parser works on real data, hook IPC is scaffolded, and reversible Claude/Codex hook installation exists. Sparkle auto-update remains pre-release wiring. See [`docs/ROADMAP.md`](./docs/ROADMAP.md).

## Quick run (from source)

```bash
git clone https://github.com/<owner>/TokenIsland.git
cd TokenIsland
swift run TokenIsland          # launches the menu-bar-less notch app
```

You should see a black pill at your notch with `TokenIsland · <today total>`.
Hover to expand. The Today row will read your real `~/.claude/projects/**/*.jsonl` and `~/.codex/sessions/**/*.jsonl`.

There is also a one-shot CLI verifier that prints what the parser sees:

```bash
swift run TokenIslandVerify
```

On Apple Silicon machines, the project includes a local run script that forces
native `arm64` SwiftPM builds and launches a staged `.app` bundle. Development
builds do not start Sparkle unless `SUFeedURL` is configured with a real HTTPS
appcast URL:

```bash
./script/build_and_run.sh          # build and launch dist/TokenIsland.app
./script/build_and_run.sh --verify # launch and assert the process is running
```

Optional hook-management commands:

```bash
swift run TokenIsland install     # add tokenisland-managed hooks
swift run TokenIsland uninstall   # remove tokenisland-managed hooks
swift run TokenIsland doctor      # print install state and paths
```

## First launch (DMG / Gatekeeper)

TokenIsland is **ad-hoc signed**, not signed with an Apple Developer ID
(we deliberately stay free of the $99/year Developer Program). On a clean
Mac the first time you double-click `TokenIsland.app` from Finder you will
see a dialog that says *"TokenIsland cannot be opened because Apple cannot
check it for malicious software."*

This is the expected behaviour for any GitHub-Releases-distributed app.
Pick **one** workaround:

```bash
# Option A — Terminal (no UI clicks)
open /Applications/TokenIsland.app

# Option B — Finder right-click trick
#   Right-click TokenIsland.app → Open → Open in the dialog.
#   macOS will remember the trust decision for next time.

# Option C — strip quarantine bit, then double-click works
xattr -d com.apple.quarantine /Applications/TokenIsland.app
```

`open` succeeds regardless of `spctl --assess` saying "rejected"; the
rejection is informational for ad-hoc signatures.

## Requirements

| Component | Version |
|---|---|
| macOS | 14.0 (Sonoma) + |
| Swift toolchain | 5.9 + |
| Claude Code sessions in `~/.claude/projects/**/*.jsonl` | optional |
| Codex CLI sessions in `~/.codex/sessions/**/*.jsonl` | optional |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TokenIsland (this repo)                  │
├─────────────────────────────────────────────────────────────┤
│  Sources/TokenIslandCore  — pure data: Parsers + Models     │
│    ├─ Parsing/ClaudeJsonlParser.swift                       │
│    ├─ Parsing/CodexJsonlParser.swift                        │
│    ├─ Parsing/TokenUsageScanner.swift                       │
│    ├─ Models/TokenUsage.swift                               │
│    ├─ Models/SessionModel.swift                             │
│    └─ IPC/HookEvent.swift                                   │
│                                                              │
│  Sources/TokenIsland     — AppKit/SwiftUI executable         │
│    ├─ AppDelegate, TokenIslandLaunch (@main)                 │
│    ├─ NotchPanelView    (SwiftUI panel)                      │
│    ├─ PanelWindowController (notch geometry)                 │
│    ├─ AppState         (sessions store)                      │
│    ├─ HookServer       (Unix-domain socket IPC)              │
│    └─ TokenUsageStore  (background sampler)                  │
│                                                              │
│  Sources/TokenIslandBridge — small CLI binary used by hooks  │
│  Sources/TokenIslandVerify — dev tool, prints parsed totals  │
└─────────────────────────────────────────────────────────────┘
                       ▼
              /tmp/tokenisland-<uid>.sock
                       ▼
  Claude Code / Codex CLI hooks → JSON-lines events
```

## License

MIT — see [LICENSE](./LICENSE).
