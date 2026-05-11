import XCTest
@testable import TokenIslandCore

final class ClaudeJsonlParserTests: XCTestCase {

    func testParsesAssistantUsageLine() throws {
        let tempFile = makeFixture(lines: [
            #"{"type":"user","message":{"content":"hi"}}"#,
            #"{"type":"assistant","timestamp":"2026-05-11T10:00:00.000Z","message":{"model":"claude-opus-4-7","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":20,"cache_read_input_tokens":10}}}"#,
            #"{"type":"assistant","timestamp":"2026-05-11T11:00:00.000Z","message":{"model":"claude-opus-4-7","usage":{"input_tokens":40,"output_tokens":30}}}"#,
        ])
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var snap = TokenSnapshot()
        ClaudeJsonlParser.parse(fileURL: tempFile, into: &snap)

        XCTAssertEqual(snap.perBucket.count, 1, "two events on same date should land in same bucket")
        let key = BucketKey(date: ISO8601DateFormatter.fixture.date(from: "2026-05-11T10:00:00.000Z")!)
        let model = snap.perBucket[key]?["claude-opus-4-7"]
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.raw, 100 + 50 + 20 + 10 + 40 + 30)
        XCTAssertEqual(model?.billable, 100 + 50 + 20 + 40 + 30)
    }

    func testSkipsLinesWithoutUsage() throws {
        let tempFile = makeFixture(lines: [
            #"{"type":"assistant","timestamp":"2026-05-11T10:00:00.000Z","message":{"model":"claude-opus-4-7"}}"#,
            #"{"type":"system","content":"ignored"}"#,
            "not json at all",
        ])
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var snap = TokenSnapshot()
        ClaudeJsonlParser.parse(fileURL: tempFile, into: &snap)
        XCTAssertTrue(snap.perBucket.isEmpty)
    }

    private func makeFixture(lines: [String]) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("claude-test-\(UUID().uuidString).jsonl")
        let body = lines.joined(separator: "\n") + "\n"
        try? body.data(using: .utf8)?.write(to: url)
        return url
    }
}

private extension ISO8601DateFormatter {
    static let fixture: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
