# Token usage cache identity strategy

## Context

`TokenUsageFileCache` (in `Sources/TokenIslandCore/Parsing/TokenUsageScanner.swift`) persists per-file `TokenSnapshot` results to `~/Library/Caches/dev.tokenisland.app/` so unchanged Claude / Codex jsonl files don't have to be re-parsed on every scan. The cache hits across app restarts; within a single hot run, every appended event invalidates the cache for the file being written.

The first iteration keyed entries on `(file size, modification time)` alone. That key was incidentally chosen — not a considered trade-off — and is too weak: any two writes that produce identical size and identical mtime resolve to a stale cache hit. The accompanying tests had codified this stale-read behavior as a desired contract, which would have made future fixes harder.

## Decision

Cache identity is `(file size, content modification time, SHA-256 of the first 4 KB)`, persisted as a new schema version. The schema version is bumped on every breaking change to the cache file's shape — the version number in JSON **and** the version suffix in the filename — so old cache files end up as orphaned artifacts that the OS reaps from `~/Library/Caches/` and never silently feed into a new schema.

Concretely for this change:

- `FileIdentity` adds `headHashHex: String`, computed as `SHA256(first min(fileSize, 4096) bytes).hexEncoded()`.
- `PersistedCache.schemaVersion` bumps from `1` → `2`.
- Default cache URL renames from `token-usage-cache-v1.json` → `token-usage-cache-v2.json`.
- Loading a file whose internal `schemaVersion != 2` is treated the same as a missing cache — start empty, rebuild on demand.

## Considered options

| Cache key | Why rejected |
| --- | --- |
| `(size, mtime)` — the current incidental key | Same-size + same-mtime overwrites silently return stale data; tests had codified the staleness as a contract |
| `(size, mtime, inode)` | Same staleness window; adds nothing for non-rename edits, breaks across rename / replace |
| `head-N-bytes raw` stored verbatim (not hashed) | Cache file grows by `4 KB × file_count` (≈ 770 KB JSON after base64) — ~80× the hash variant for no gain |
| `whole-file content hash` | Cost ≈ half of re-parse; defeats the cache's purpose for large session files |
| `offset + parsed-prefix hash` (true append-only incremental scan) | Reserved for a future schema bump — solves a different problem (cold-scan latency) and is out of scope for this fix |

| Head hash window | Why 4 KB | Why not the others |
| --- | --- | --- |
| **4 KB (chosen)** | Block-aligned with APFS/SSD page size — reading 64 bytes already costs 4 KB; defense-in-depth at zero extra cost; diagnosable via `head -c 4096 file.jsonl \| shasum -a 256` | — |
| 64–256 bytes | Smaller hex strings, but no measurable cost saving once the read happens at page granularity; harder to align with future offset-based incremental scan | Rejected |
| First-line (variable) | Couples cache identity to parser semantics; Codex `session_meta` first line is ~22 KB which makes the variable window *more* expensive than the fixed window | Rejected |
| 64 KB+ | Effectively whole-file hash for typical session sizes | Rejected |

| Hash algorithm | Decision |
| --- | --- |
| **SHA-256** (`CryptoKit.SHA256`) | Stable across Swift versions, hardware-accelerated on Apple Silicon, no `Insecure.*` namespace warning, same algorithm a future incremental-prefix hash will want |
| SHA-1 / MD5 | Functional but flagged as `Insecure` in CryptoKit, no real saving at 4 KB |
| `Hasher` / `hashValue` | Swift-version-unstable seed — disqualified for a persisted key |

| Schema evolution strategy | Decision |
| --- | --- |
| **Bump version + rename file** | Diff-visible signal of breaking change; old files orphan harmlessly |
| Bump version only, reuse filename | Internal vs. filename version disagree — ambiguous "source of truth" |
| Keep v1, make new field optional | Backwards-compat code path for users who don't exist (cache never shipped) |
| Keep v1, silently break decode | Saves three lines today, sets precedent for implicit schema drift tomorrow |

## Consequences

- **Cache invalidation matches reality.** Same-size + same-mtime + different content (editor in-place save, `touch -t` rollback, test fixtures) no longer silently feeds stale token counts into the panel.
- **Schema evolution has a documented protocol.** Every future change to `PersistedCache` or `FileIdentity` follows the same recipe: bump `schemaVersion`, rename the file suffix, update the migration test. No silent field additions.
- **Orphaned `token-usage-cache-v1.json` may sit in `~/Library/Caches/dev.tokenisland.app/` on developer machines** that built this branch before the fix. macOS reaps `Caches/` content under disk pressure; we deliberately don't write migration code for a single-developer artifact.
- **Cold-scan latency is unchanged.** This ADR does not address the ~16 s first-scan time on ~145 Codex files; that requires an append-only incremental scan (offset + parsed-prefix hash), reserved for a future schema bump.
- **Test suite gains four anchored behaviors:** truly-unchanged → cache hit; forged metadata + different content → cache miss; real metadata change → cache miss; on-disk `schemaVersion: 1` file → ignored and rebuilt.
- **No implementation constants are pinned in tests.** The 4 KB window and SHA-256 choice live only in the code, so future tuning doesn't have to fight the test suite.
