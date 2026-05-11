import Foundation

public enum SessionStatus: String, Codable, Sendable {
    case idle
    case running
    case waitingForPermission = "waiting_for_permission"
    case waitingForAnswer = "waiting_for_answer"
    case error
    case finished
}

public struct SessionInfo: Identifiable, Sendable, Codable {
    public let id: String
    public let source: AgentSource
    public var status: SessionStatus
    public var lastEventAt: Date
    public var cwd: String?
    public var title: String?
    public var lastToolName: String?
    public var lastMessage: String?
    public var pendingPrompt: String?

    public init(
        id: String,
        source: AgentSource,
        status: SessionStatus = .idle,
        lastEventAt: Date = Date(),
        cwd: String? = nil,
        title: String? = nil,
        lastToolName: String? = nil,
        lastMessage: String? = nil,
        pendingPrompt: String? = nil
    ) {
        self.id = id
        self.source = source
        self.status = status
        self.lastEventAt = lastEventAt
        self.cwd = cwd
        self.title = title
        self.lastToolName = lastToolName
        self.lastMessage = lastMessage
        self.pendingPrompt = pendingPrompt
    }
}
