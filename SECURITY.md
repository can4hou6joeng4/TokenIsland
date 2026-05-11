# Security Policy

## Supported versions

TokenIsland is pre-1.0. Only the latest tagged release is supported.

| Version | Supported |
| --- | --- |
| latest tag | ✅ |
| anything older | ❌ |

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security-sensitive reports.

Instead, email the maintainer at the address listed on the GitHub profile of this repository's owner, or open a [Private Security Advisory](https://docs.github.com/en/code-security/security-advisories/repository-security-advisories/about-repository-security-advisories) on this repository.

Include:
- A description of the issue and its impact.
- Reproduction steps or proof-of-concept.
- Any logs or stack traces.

We aim to acknowledge reports within 7 days and to ship a fix or mitigation within 30 days of acknowledgement, depending on severity.

## Threat model boundaries

TokenIsland reads local session files in `~/.claude/projects` and `~/.codex`, and listens on a per-UID Unix-domain socket at `/tmp/tokenisland-<uid>.sock`. It does not make outbound network requests except for Sparkle update checks against the configured `SUFeedURL`.

Notable considerations:
- The socket is mode `0600` and bound to the invoking user only. Other local users on the same machine cannot connect.
- The hook installer modifies `~/.claude/settings.json` and `$CODEX_HOME/hooks.json`. All managed entries are tagged with `_managedBy: "tokenisland-managed"` so `uninstall` can revert cleanly.
- Bridge binary receives stdin from the AI CLI and forwards it as a single line to the socket. It does not execute shell commands.
