import XCTest
@testable import TokenIslandCore

final class HookEventTests: XCTestCase {

    func testRoundTripEncoding() {
        let original = HookEvent(
            source: .claude,
            sessionId: "abc-123",
            kind: .toolStart,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cwd: "/Users/x/project",
            toolName: "Bash",
            message: nil,
            prompt: nil
        )
        guard let data = original.encode() else {
            XCTFail("encode returned nil")
            return
        }
        guard let decoded = HookEvent.decode(data) else {
            XCTFail("decode returned nil")
            return
        }
        XCTAssertEqual(decoded.source, .claude)
        XCTAssertEqual(decoded.sessionId, "abc-123")
        XCTAssertEqual(decoded.kind, .toolStart)
        XCTAssertEqual(decoded.cwd, "/Users/x/project")
        XCTAssertEqual(decoded.toolName, "Bash")
    }

    func testKindRawValuesAreStable() {
        XCTAssertEqual(HookEvent.Kind.toolStart.rawValue, "tool_start")
        XCTAssertEqual(HookEvent.Kind.permissionRequest.rawValue, "permission_request")
        XCTAssertEqual(HookEvent.Kind.sessionStart.rawValue, "session_start")
    }

    func testAgentSourceCases() {
        XCTAssertEqual(AgentSource.allCases.count, 2)
        XCTAssertEqual(AgentSource.claude.displayName, "Claude Code")
        XCTAssertEqual(AgentSource.codex.displayName, "Codex")
    }
}
