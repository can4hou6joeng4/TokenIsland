import Foundation

public struct HookEvent: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case toolStart = "tool_start"
        case toolEnd = "tool_end"
        case permissionRequest = "permission_request"
        case questionAsked = "question_asked"
        case stop
        case notification
    }

    public let source: AgentSource
    public let sessionId: String
    public let kind: Kind
    public let timestamp: Date
    public let cwd: String?
    public let toolName: String?
    public let message: String?
    public let prompt: String?

    public init(
        source: AgentSource,
        sessionId: String,
        kind: Kind,
        timestamp: Date = Date(),
        cwd: String? = nil,
        toolName: String? = nil,
        message: String? = nil,
        prompt: String? = nil
    ) {
        self.source = source
        self.sessionId = sessionId
        self.kind = kind
        self.timestamp = timestamp
        self.cwd = cwd
        self.toolName = toolName
        self.message = message
        self.prompt = prompt
    }
}

public extension HookEvent {
    static func decode(_ data: Data) -> HookEvent? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HookEvent.self, from: data)
    }

    func encode() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
}
