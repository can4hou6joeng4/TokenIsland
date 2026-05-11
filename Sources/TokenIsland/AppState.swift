import Foundation
import SwiftUI
import TokenIslandCore

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [SessionInfo] = []
    @Published var isPanelExpanded: Bool = false

    func apply(_ event: HookEvent) {
        let idx = sessions.firstIndex { $0.id == event.sessionId && $0.source == event.source }
        var session = idx.map { sessions[$0] } ?? SessionInfo(id: event.sessionId, source: event.source)

        session.lastEventAt = event.timestamp
        if let cwd = event.cwd { session.cwd = cwd }
        if let tool = event.toolName { session.lastToolName = tool }
        if let msg = event.message { session.lastMessage = msg }
        if let p = event.prompt { session.pendingPrompt = p }

        switch event.kind {
        case .sessionStart:
            session.status = .running
        case .sessionEnd, .stop:
            session.status = .finished
        case .toolStart, .toolEnd, .notification:
            session.status = .running
        case .permissionRequest:
            session.status = .waitingForPermission
        case .questionAsked:
            session.status = .waitingForAnswer
        }

        if let idx = idx {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }

        sessions.sort { $0.lastEventAt > $1.lastEventAt }
        pruneStale()
    }

    func session(by id: String, source: AgentSource) -> SessionInfo? {
        sessions.first { $0.id == id && $0.source == source }
    }

    private func pruneStale(maxAge: TimeInterval = 60 * 60 * 4) {
        let cutoff = Date().addingTimeInterval(-maxAge)
        sessions.removeAll { $0.status == .finished && $0.lastEventAt < cutoff }
    }

    var activeSessionCount: Int {
        sessions.filter { $0.status != .finished && $0.status != .idle }.count
    }

    var hasPendingInteraction: Bool {
        sessions.contains {
            $0.status == .waitingForPermission || $0.status == .waitingForAnswer
        }
    }
}
