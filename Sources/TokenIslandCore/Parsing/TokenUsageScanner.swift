import Foundation

public struct TokenUsageScanner {
    public let claudeDir: URL
    public let codexDir: URL
    private let cache: TokenUsageFileCache

    public init(claudeDir: URL? = nil, codexDir: URL? = nil, cacheURL: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDir = claudeDir ?? home.appendingPathComponent(".claude/projects")
        self.codexDir = codexDir ?? home.appendingPathComponent(".codex")
        let storageURL = cacheURL ?? ((claudeDir == nil && codexDir == nil) ? Self.defaultCacheURL : nil)
        self.cache = TokenUsageFileCache(storageURL: storageURL)
    }

    public func scanClaude(since cutoff: Date? = nil) -> TokenSnapshot {
        var snap = TokenSnapshot()
        let files = listJsonlFiles(root: claudeDir, since: cutoff)
        for f in files {
            snap.merge(cache.snapshot(for: f) { file in
                var fileSnapshot = TokenSnapshot()
                ClaudeJsonlParser.parse(fileURL: file, into: &fileSnapshot)
                return fileSnapshot
            })
        }
        cache.flush()
        return snap
    }

    public func scanCodex(since cutoff: Date? = nil) -> TokenSnapshot {
        var snap = TokenSnapshot()
        let sessions = codexDir.appendingPathComponent("sessions")
        let archived = codexDir.appendingPathComponent("archived_sessions")
        var files = listJsonlFiles(root: sessions, since: cutoff)
        files.append(contentsOf: listJsonlFiles(root: archived, since: cutoff, recursive: false))
        for f in files {
            snap.merge(cache.snapshot(for: f) { file in
                var fileSnapshot = TokenSnapshot()
                CodexJsonlParser.parse(fileURL: file, into: &fileSnapshot)
                return fileSnapshot
            })
        }
        cache.flush()
        return snap
    }

    func listJsonlFiles(root: URL, since cutoff: Date? = nil, recursive: Bool = true) -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }
        var results: [URL] = []
        if recursive {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }
            for case let url as URL in enumerator {
                guard url.pathExtension == "jsonl" else { continue }
                if let cutoff = cutoff,
                   let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   mtime < cutoff { continue }
                results.append(url)
            }
        } else {
            let contents = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in contents where url.pathExtension == "jsonl" {
                if let cutoff = cutoff,
                   let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   mtime < cutoff { continue }
                results.append(url)
            }
        }
        return results
    }

    private static var defaultCacheURL: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches
            .appendingPathComponent("dev.tokenisland.app", isDirectory: true)
            .appendingPathComponent("token-usage-cache-v1.json")
    }
}

private extension TokenSnapshot {
    mutating func merge(_ other: TokenSnapshot) {
        for (bucket, models) in other.perBucket {
            for (model, counts) in models {
                bump(bucket: bucket, model: model, counts: counts)
            }
        }
    }
}

private final class TokenUsageFileCache: @unchecked Sendable {
    private struct FileIdentity: Codable, Equatable {
        let size: Int
        let modificationTime: TimeInterval

        init?(file: URL) {
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let modificationDate = values.contentModificationDate
            else { return nil }

            self.size = size
            self.modificationTime = modificationDate.timeIntervalSinceReferenceDate
        }
    }

    private struct Entry: Codable {
        let identity: FileIdentity
        let snapshot: TokenSnapshot
    }

    private struct PersistedCache: Codable {
        let schemaVersion: Int
        let entries: [String: Entry]
    }

    private static let schemaVersion = 1

    private let lock = NSLock()
    private let storageURL: URL?
    private var entries: [String: Entry] = [:]
    private var isDirty = false

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        guard let storageURL,
              let data = try? Data(contentsOf: storageURL),
              let persisted = try? JSONDecoder().decode(PersistedCache.self, from: data),
              persisted.schemaVersion == Self.schemaVersion
        else { return }

        self.entries = persisted.entries
    }

    func snapshot(for file: URL, parse: (URL) -> TokenSnapshot) -> TokenSnapshot {
        guard let identity = FileIdentity(file: file) else {
            return parse(file)
        }

        lock.lock()
        if let entry = entries[file.path], entry.identity == identity {
            let snapshot = entry.snapshot
            lock.unlock()
            return snapshot
        }
        lock.unlock()

        let snapshot = parse(file)

        lock.lock()
        entries[file.path] = Entry(identity: identity, snapshot: snapshot)
        isDirty = true
        lock.unlock()
        return snapshot
    }

    func flush() {
        guard let storageURL else { return }

        lock.lock()
        guard isDirty else {
            lock.unlock()
            return
        }
        let entries = self.entries
        isDirty = false
        lock.unlock()

        let persisted = PersistedCache(schemaVersion: Self.schemaVersion, entries: entries)
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            lock.lock()
            isDirty = true
            lock.unlock()
        }
    }
}

public struct AggregatedUsage: Sendable {
    public let claude: TokenSnapshot
    public let codex: TokenSnapshot

    public init(claude: TokenSnapshot = TokenSnapshot(), codex: TokenSnapshot = TokenSnapshot()) {
        self.claude = claude
        self.codex = codex
    }

    public func todayTotal(mode: TokenMode = .billable, now: Date = Date()) -> (claude: Int, codex: Int) {
        (claude.today(mode: mode, now: now), codex.today(mode: mode, now: now))
    }
}
