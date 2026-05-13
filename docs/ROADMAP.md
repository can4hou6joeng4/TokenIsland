# Roadmap

## Done

- ✅ SwiftPM project skeleton (Core / App / Bridge / Verify)
- ✅ Claude jsonl parser (verified against ~/.claude/projects, 24 files, 0.87s)
- ✅ Codex jsonl parser (verified against ~/.codex/sessions, 145 files, 16.17s)
- ✅ Data model: `TokenSnapshot` / `TokenCounts` (raw + billable)
- ✅ Notch panel SwiftUI view + `PanelWindowController` (positions at screen safe-area top)
- ✅ `AppState` session state machine
- ✅ `HookServer` Unix-domain socket listener
- ✅ `TokenUsageStore` background sampler (60s refresh)
- ✅ Today row in notch (Claude + Codex compact totals)
- ✅ Claude Code hook installer + uninstaller (managed `~/.claude/settings.json` entries)
- ✅ Codex CLI hook installer + uninstaller (managed `$CODEX_HOME/hooks.json` entries)
- ✅ `TokenIslandBridge` hook forwarding into the app socket
- ✅ `build.sh` producing a universal `.app` bundle + `.dmg`
- ✅ GitHub Actions release workflow
- ✅ Pre-flight `doctor` CLI (paths + permissions check)
- ✅ `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`
- ✅ Apple Silicon local run script (`script/build_and_run.sh`)
- ✅ Sparkle updater guard for missing or placeholder appcast URLs

## Next

- [ ] Codex jsonl incremental cache (current cold scan ~16s on 145 files)
- [ ] 7-day stacked bar chart on panel expansion (Swift Charts)
- [ ] Settings window (General / Behavior / Appearance / Hooks / About)
- [ ] Sparkle auto-update wired with `appcast.xml`
- [ ] Localized strings (en + zh-Hans)
- [ ] Mascot animations for Claude / Codex
- [ ] Hook installer fixture tests for JSON/TOML round-trips
- [ ] End-to-end install smoke test against temporary Claude/Codex homes
