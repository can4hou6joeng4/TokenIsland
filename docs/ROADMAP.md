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

## Next

- [ ] Codex jsonl incremental cache (current cold scan ~16s on 145 files)
- [ ] Claude Code hook installer + uninstaller (write to `~/.claude/settings.json` hooks block)
- [ ] Codex CLI integration — either AppServer client or polling fallback
- [ ] `TokenIslandBridge` end-to-end: hook script → bridge → socket → AppState
- [ ] 7-day stacked bar chart on panel expansion (Swift Charts)
- [ ] Settings window (General / Behavior / Appearance / Hooks / About)
- [ ] Sparkle auto-update wired with `appcast.xml`
- [ ] `build.sh` producing universal `.app` bundle + `.dmg`
- [ ] GitHub Actions release workflow
- [ ] Localized strings (en + zh-Hans)
- [ ] Mascot animations for Claude / Codex
- [ ] Pre-flight `doctor` CLI (paths + permissions check)
- [ ] `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`
