import XCTest
@testable import TokenIslandCore

final class TokenUsageScannerTests: XCTestCase {
    func testCodexScanReparsesWhenContentChangesEvenWithForgedMetadata() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try makeCodexLogFile(root: root, totalTokens: 100)
        let stableModificationDate = Date(timeIntervalSince1970: 1_700_000_000)
        try setModificationDate(stableModificationDate, for: file)

        let scanner = TokenUsageScanner(claudeDir: root.appendingPathComponent("missing-claude"), codexDir: root)

        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 100)

        let replacement = codexFixture(totalTokens: 900)
        XCTAssertEqual(replacement.utf8.count, codexFixture(totalTokens: 100).utf8.count)
        try replacement.write(to: file, atomically: true, encoding: .utf8)
        try setModificationDate(stableModificationDate, for: file)

        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 900)
    }

    func testCodexScanInvalidatesCachedSnapshotWhenFileMetadataChanges() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try makeCodexLogFile(root: root, totalTokens: 100)
        try setModificationDate(Date(timeIntervalSince1970: 1_700_000_000), for: file)

        let scanner = TokenUsageScanner(claudeDir: root.appendingPathComponent("missing-claude"), codexDir: root)

        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 100)

        try codexFixture(totalTokens: 900).write(to: file, atomically: true, encoding: .utf8)
        try setModificationDate(Date(timeIntervalSince1970: 1_700_000_060), for: file)

        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 900)
    }

    func testCodexScanReusesCachedSnapshotWhenOnlyTailBytesDiffer() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try makeLargeCodexLogFile(root: root, totalTokens: 100)
        let stableModificationDate = Date(timeIntervalSince1970: 1_700_000_000)
        try setModificationDate(stableModificationDate, for: file)

        let scanner = TokenUsageScanner(claudeDir: root.appendingPathComponent("missing-claude"), codexDir: root)
        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 100)

        let replacement = largeCodexFixture(totalTokens: 900)
        XCTAssertEqual(replacement.utf8.count, largeCodexFixture(totalTokens: 100).utf8.count)
        XCTAssertGreaterThan(replacement.utf8.count, 4096)
        try replacement.write(to: file, atomically: true, encoding: .utf8)
        try setModificationDate(stableModificationDate, for: file)

        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 100)
    }

    func testCodexScanPersistsCachedSnapshotAcrossScannerInstances() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheFile = root.appendingPathComponent("token-usage-cache.json")
        let file = try makeLargeCodexLogFile(root: root, totalTokens: 100)
        let stableModificationDate = Date(timeIntervalSince1970: 1_700_000_000.123456)
        try setModificationDate(stableModificationDate, for: file)

        let firstScanner = TokenUsageScanner(
            claudeDir: root.appendingPathComponent("missing-claude"),
            codexDir: root,
            cacheURL: cacheFile
        )
        XCTAssertEqual(firstScanner.scanCodex().total(mode: .billable), 100)

        let replacement = largeCodexFixture(totalTokens: 900)
        XCTAssertEqual(replacement.utf8.count, largeCodexFixture(totalTokens: 100).utf8.count)
        try replacement.write(to: file, atomically: true, encoding: .utf8)
        try setModificationDate(stableModificationDate, for: file)

        let secondScanner = TokenUsageScanner(
            claudeDir: root.appendingPathComponent("missing-claude"),
            codexDir: root,
            cacheURL: cacheFile
        )
        XCTAssertEqual(secondScanner.scanCodex().total(mode: .billable), 100)
    }

    func testLegacyV1CacheFileIsIgnored() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheFile = root.appendingPathComponent("token-usage-cache-v1.json")
        let legacy = #"{"schemaVersion":1,"entries":{}}"#
        try legacy.write(to: cacheFile, atomically: true, encoding: .utf8)

        let file = try makeCodexLogFile(root: root, totalTokens: 777)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let scanner = TokenUsageScanner(
            claudeDir: root.appendingPathComponent("missing-claude"),
            codexDir: root,
            cacheURL: cacheFile
        )
        XCTAssertEqual(scanner.scanCodex().total(mode: .billable), 777)

        let written = try Data(contentsOf: cacheFile)
        let parsed = try JSONSerialization.jsonObject(with: written) as? [String: Any]
        XCTAssertEqual(parsed?["schemaVersion"] as? Int, 2)
        XCTAssertNotNil(parsed?["entries"] as? [String: Any])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("tokenisland-scanner-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeCodexLogFile(root: URL, totalTokens: Int) throws -> URL {
        let sessionDir = root
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent("2026", isDirectory: true)
            .appendingPathComponent("05", isDirectory: true)
            .appendingPathComponent("14", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let file = sessionDir.appendingPathComponent("session.jsonl")
        try codexFixture(totalTokens: totalTokens).write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func makeLargeCodexLogFile(root: URL, totalTokens: Int) throws -> URL {
        let sessionDir = root
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent("2026", isDirectory: true)
            .appendingPathComponent("05", isDirectory: true)
            .appendingPathComponent("14", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let file = sessionDir.appendingPathComponent("session-large.jsonl")
        try largeCodexFixture(totalTokens: totalTokens).write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func setModificationDate(_ date: Date, for file: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
    }

    private func codexFixture(totalTokens: Int) -> String {
        """
        {"type":"turn_context","payload":{"model":"gpt-5.5"}}
        {"payload":{"type":"token_count","timestamp":"2026-05-14T00:00:00.000Z","info":{"total_token_usage":{"total_tokens":\(totalTokens)}}}}

        """
    }

    private func largeCodexFixture(totalTokens: Int) -> String {
        var lines: [String] = [#"{"type":"turn_context","payload":{"model":"gpt-5.5"}}"#]
        for index in 0..<80 {
            lines.append(#"{"type":"noise","payload":{"index":\#(String(format: "%05d", index)),"text":"padding-padding-padding-padding-padding"}}"#)
        }
        lines.append(#"{"payload":{"type":"token_count","timestamp":"2026-05-14T00:00:00.000Z","info":{"total_token_usage":{"total_tokens":\#(totalTokens)}}}}"#)
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
