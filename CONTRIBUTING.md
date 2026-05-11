# Contributing to TokenIsland

Thanks for taking the time to contribute.

## Quick start for contributors

```bash
git clone https://github.com/<owner>/TokenIsland.git
cd TokenIsland
swift build
swift run TokenIslandVerify    # sanity check the jsonl parsers against your local sessions
swift run TokenIsland help     # CLI overview
```

Requires macOS 14+ and Swift 5.9+.

## Branch & commit conventions

- Branch from `main`. Suggested prefixes: `feat/`, `fix/`, `docs/`, `refactor/`, `perf/`, `chore/`.
- Commit subjects use the format `type: 中文描述` — keep them under 50 characters, no scope brackets, no file names or identifiers.
- Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Group small commits into a single logical change when feasible. Squash on merge.

## Pull requests

1. Open against `main`.
2. Make sure `swift build` and `swift test` (once tests exist) pass locally.
3. Update `CHANGELOG.md` under `[Unreleased]` with a one-line summary.
4. Reference the issue you are closing in the PR description, not the commit message.

## Code style

- Match the surrounding file. We do not run `swift-format` yet; consistency over personal preference.
- Public API in `TokenIslandCore` should keep zero UI dependencies — keep `AppKit`/`SwiftUI` imports inside `Sources/TokenIsland`.
- Comments are reserved for non-obvious *why*; do not narrate what code already says.

## Reporting issues

Use the templates under `.github/ISSUE_TEMPLATE/`. Include:
- macOS version, Swift toolchain version, MacBook model (notch / no notch).
- `TokenIsland doctor` output.
- Reproduction steps.
