# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- SwiftPM project skeleton with `TokenIslandCore`, `TokenIsland`, `TokenIslandBridge`, and `TokenIslandVerify` targets.
- Claude jsonl parser (`Sources/TokenIslandCore/Parsing/ClaudeJsonlParser.swift`).
- Codex jsonl parser (`Sources/TokenIslandCore/Parsing/CodexJsonlParser.swift`).
- File-level token usage cache for Claude and Codex jsonl scans, persisted under the user cache directory to avoid full rescans after app restart.
- Notch panel UI (`NotchPanelView`) with idle/expanded states and a Today total row.
- `HookServer` Unix-domain socket IPC, listening at `/tmp/tokenisland-<uid>.sock`.
- `HookInstaller` that safely merges hook entries into `~/.claude/settings.json` and `$CODEX_HOME/hooks.json`, with reversible uninstall.
- CLI subcommands: `install`, `uninstall`, `doctor`, `help`.
- `build.sh` producing a universal `.app` bundle and DMG.
- GitHub Actions CI and Release workflows.
- Apple Silicon development run script that forces native `arm64` SwiftPM builds and launches a staged `.app` bundle.
- Codex environment Run action wired to `script/build_and_run.sh`.
- Generated TokenIsland app icon resources for release bundles.

### Notes
- Hook installer writes JSON via `JSONSerialization` and currently re-orders keys when round-tripping. Round-trip is **semantically** equal to the input; byte-level minimal-diff write is on the roadmap.
- DMG is ad-hoc signed (`codesign -s -`). On first launch, macOS Gatekeeper may show a warning; use Right-click → Open or `xattr -d com.apple.quarantine` to bypass. See README §"First launch" for details.

### Fixed
- `build.sh` now embeds `Sparkle.framework` into `Contents/Frameworks/` and adds the `@executable_path/../Frameworks` rpath. Without this the .app bundle launched from the DMG dyld-failed because `@rpath/Sparkle.framework/...` could not be resolved.
- `build.sh` now copies `Resources/AppIcon.icns` into the app bundle so Finder and Launch Services can display the app icon referenced by `Info.plist`.
- Token usage refreshes now reuse cached per-file scan results, removing repeated CPU spikes from unchanged large Claude and Codex session logs.
- `TokenIsland install` now checks packaged `.app/Contents/Helpers/tokenisland-bridge`, matching the DMG bundle layout.
- Removed the stale SwiftPM `Resources` declaration so clean builds no longer warn about a missing resource directory.
- Sparkle updater now stays disabled when `SUFeedURL` is missing, invalid, or still using placeholder release metadata.
