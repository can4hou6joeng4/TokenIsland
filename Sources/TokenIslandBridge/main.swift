import Foundation
import TokenIslandCore

struct CLIArgs {
    var source: String = ""
    var kind: String = ""
    var sessionId: String = ""
    var cwd: String = ""
    var toolName: String = ""
}

func parseArgs(_ argv: [String]) -> CLIArgs {
    var args = CLIArgs()
    var i = 1
    while i < argv.count {
        let key = argv[i]
        let value = (i + 1 < argv.count) ? argv[i + 1] : ""
        switch key {
        case "--source": args.source = value; i += 2
        case "--kind": args.kind = value; i += 2
        case "--session-id": args.sessionId = value; i += 2
        case "--cwd": args.cwd = value; i += 2
        case "--tool": args.toolName = value; i += 2
        default: i += 1
        }
    }
    return args
}

let args = parseArgs(CommandLine.arguments)
let env = ProcessInfo.processInfo.environment

let payloadData = (try? FileHandle.standardInput.readToEnd()) ?? Data()
let payloadString = String(data: payloadData, encoding: .utf8) ?? ""

func extract(_ key: String) -> String? {
    guard !payloadString.isEmpty,
          let data = payloadString.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    if let s = obj[key] as? String { return s }
    return nil
}

let source = args.source.isEmpty ? (env["TOKEN_ISLAND_SOURCE"] ?? "claude") : args.source
let kind = args.kind.isEmpty ? (extract("hook_event_name") ?? "Notification") : args.kind
let sessionId = args.sessionId.isEmpty ? (extract("session_id") ?? env["CLAUDE_SESSION_ID"] ?? env["CODEX_SESSION_ID"] ?? "default") : args.sessionId
let cwd = args.cwd.isEmpty ? (extract("cwd") ?? FileManager.default.currentDirectoryPath) : args.cwd
let toolName = args.toolName.isEmpty ? (extract("tool_name") ?? "") : args.toolName

func mapKind(_ raw: String) -> HookEvent.Kind {
    switch raw {
    case "SessionStart", "session_start": return .sessionStart
    case "SessionEnd", "session_end": return .sessionEnd
    case "PreToolUse", "BeforeTool", "pre_tool_use": return .toolStart
    case "PostToolUse", "AfterTool", "post_tool_use": return .toolEnd
    case "PostToolUseFailure": return .toolEnd
    case "PermissionRequest", "permission_request": return .permissionRequest
    case "UserPromptSubmit": return .questionAsked
    case "Stop", "stop": return .stop
    case "SubagentStart": return .toolStart
    case "SubagentStop": return .toolEnd
    case "Notification": return .notification
    default: return .notification
    }
}

let agentSource: AgentSource = (source.lowercased() == "codex") ? .codex : .claude
let event = HookEvent(
    source: agentSource,
    sessionId: sessionId,
    kind: mapKind(kind),
    timestamp: Date(),
    cwd: cwd.isEmpty ? nil : cwd,
    toolName: toolName.isEmpty ? nil : toolName,
    message: nil,
    prompt: nil
)

guard let encoded = event.encode() else { exit(0) }

let socketPath = TokenIslandCore.socketPath
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { exit(0) }

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = socketPath.utf8CString
withUnsafeMutableBytes(of: &addr.sun_path) { dst in
    pathBytes.withUnsafeBytes { src in
        let copyLen = min(src.count, dst.count - 1)
        dst.copyMemory(from: UnsafeRawBufferPointer(start: src.baseAddress, count: copyLen))
    }
}

let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
let connected = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
        connect(fd, sa, addrSize)
    }
}
guard connected == 0 else { close(fd); exit(0) }

_ = encoded.withUnsafeBytes { buf in
    send(fd, buf.baseAddress, buf.count, 0)
}
let newline: UInt8 = 0x0A
_ = withUnsafePointer(to: newline) { send(fd, $0, 1, 0) }
close(fd)
