import Foundation

public struct TokenUsageScanner {
    public let claudeDir: URL
    public let codexDir: URL

    public init(claudeDir: URL? = nil, codexDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDir = claudeDir ?? home.appendingPathComponent(".claude/projects")
        self.codexDir = codexDir ?? home.appendingPathComponent(".codex")
    }

    public func scanClaude(since cutoff: Date? = nil) -> TokenSnapshot {
        var snap = TokenSnapshot()
        let files = listJsonlFiles(root: claudeDir, since: cutoff)
        for f in files {
            ClaudeJsonlParser.parse(fileURL: f, into: &snap)
        }
        return snap
    }

    public func scanCodex(since cutoff: Date? = nil) -> TokenSnapshot {
        var snap = TokenSnapshot()
        let sessions = codexDir.appendingPathComponent("sessions")
        let archived = codexDir.appendingPathComponent("archived_sessions")
        var files = listJsonlFiles(root: sessions, since: cutoff)
        files.append(contentsOf: listJsonlFiles(root: archived, since: cutoff, recursive: false))
        for f in files {
            CodexJsonlParser.parse(fileURL: f, into: &snap)
        }
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
