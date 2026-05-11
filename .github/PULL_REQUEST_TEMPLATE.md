## What changed

<!-- Short summary of the change (the "why" matters more than the "what"). -->

## Related issue

Closes #

## How verified

- [ ] `swift build` passes
- [ ] `swift test` passes (when tests exist)
- [ ] `swift run TokenIslandVerify` still produces sensible output against local sessions
- [ ] `TokenIsland install` / `uninstall` round-trips remain clean

## Checklist

- [ ] Branch from `main`, conventional commit subject in `type: 中文描述` form
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] No unrelated formatting / refactoring noise in the diff
- [ ] If the change touches `~/.claude/settings.json` or `~/.codex/hooks.json` semantics, the uninstall path was tested
