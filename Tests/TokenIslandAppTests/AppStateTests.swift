import XCTest
import TokenIslandCore
@testable import TokenIsland

@MainActor
final class AppStateTests: XCTestCase {
    func testUserPromptSubmitDoesNotRequireUserAction() {
        let appState = AppState()

        appState.apply(HookEvent(
            source: .codex,
            sessionId: "codex-session",
            kind: .questionAsked,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        ))

        XCTAssertFalse(appState.hasPendingInteraction)
        XCTAssertEqual(appState.session(by: "codex-session", source: .codex)?.status, .running)
    }

    func testPermissionRequestIsClearedByLaterToolEvent() {
        let appState = AppState()
        let sessionId = "codex-session"
        let now = Date()

        appState.apply(HookEvent(
            source: .codex,
            sessionId: sessionId,
            kind: .permissionRequest,
            timestamp: now
        ))
        XCTAssertTrue(appState.hasPendingInteraction)

        appState.apply(HookEvent(
            source: .codex,
            sessionId: sessionId,
            kind: .toolStart,
            timestamp: now.addingTimeInterval(1),
            toolName: "exec_command"
        ))

        XCTAssertFalse(appState.hasPendingInteraction)
        XCTAssertEqual(appState.session(by: sessionId, source: .codex)?.status, .running)
    }

    func testPendingSessionIsPresentedBeforeFinishedSessionForSameSource() {
        let appState = AppState()
        let pendingSessionId = "pending-codex-session"
        let finishedSessionId = "finished-codex-session"
        let now = Date()

        appState.apply(HookEvent(
            source: .codex,
            sessionId: pendingSessionId,
            kind: .permissionRequest,
            timestamp: now.addingTimeInterval(-60)
        ))
        appState.apply(HookEvent(
            source: .codex,
            sessionId: finishedSessionId,
            kind: .stop,
            timestamp: now
        ))

        XCTAssertEqual(appState.sessions.first { $0.source == .codex }?.id, pendingSessionId)
        XCTAssertTrue(appState.hasPendingInteraction)
    }

    func testExpiredPendingSessionIsPruned() {
        let appState = AppState()

        appState.apply(HookEvent(
            source: .codex,
            sessionId: "stale-pending-session",
            kind: .permissionRequest,
            timestamp: Date().addingTimeInterval(-(60 * 60 * 5))
        ))

        XCTAssertFalse(appState.hasPendingInteraction)
        XCTAssertNil(appState.session(by: "stale-pending-session", source: .codex))
    }
}
