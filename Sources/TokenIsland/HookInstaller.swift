import Foundation
import TokenIslandCore

@MainActor
enum HookInstaller {
    static var installDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tokenisland", isDirectory: true)
    }
    static var bridgePath: URL { installDir.appendingPathComponent("tokenisland-bridge") }
    static var versionMarker: URL { installDir.appendingPathComponent("hooks.version") }
    static let hookSchemaVersion = 1

    static var claudeSettings: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }
    static var codexHome: URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }
    static var codexHooks: URL { codexHome.appendingPathComponent("hooks.json") }
    static var codexConfigToml: URL { codexHome.appendingPathComponent("config.toml") }

    static let managedTag = "tokenisland-managed"

    static func installAll() -> InstallReport {
        var report = InstallReport()
        ensureBridgeBinary(into: &report)
        if FileManager.default.fileExists(atPath: claudeSettings.deletingLastPathComponent().path) {
            installClaudeHooks(into: &report)
        }
        if FileManager.default.fileExists(atPath: codexHome.path) {
            installCodexHooks(into: &report)
        }
        try? "\(hookSchemaVersion)".data(using: .utf8)?.write(to: versionMarker)
        return report
    }

    static func uninstallAll() -> InstallReport {
        var report = InstallReport()
        uninstallClaudeHooks(into: &report)
        uninstallCodexHooks(into: &report)
        try? FileManager.default.removeItem(at: bridgePath)
        try? FileManager.default.removeItem(at: versionMarker)
        return report
    }

    private static func ensureBridgeBinary(into report: inout InstallReport) {
        let fm = FileManager.default
        try? fm.createDirectory(at: installDir, withIntermediateDirectories: true)

        guard let sourceURL = locateBridgeBinary() else {
            report.notes.append("[bridge] could not locate tokenisland-bridge executable on disk")
            return
        }
        do {
            if fm.fileExists(atPath: bridgePath.path) {
                try fm.removeItem(at: bridgePath)
            }
            try fm.copyItem(at: sourceURL, to: bridgePath)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgePath.path)
            report.bridgeInstalled = true
        } catch {
            report.notes.append("[bridge] copy failed: \(error.localizedDescription)")
        }
    }

    private static func locateBridgeBinary() -> URL? {
        let exec = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("tokenisland-bridge")
        if FileManager.default.isExecutableFile(atPath: exec.path) { return exec }
        if let mainExecutable = Bundle.main.executableURL {
            let sibling = mainExecutable.deletingLastPathComponent().appendingPathComponent("tokenisland-bridge")
            if FileManager.default.isExecutableFile(atPath: sibling.path) { return sibling }
        }
        return nil
    }
}

struct InstallReport {
    var bridgeInstalled: Bool = false
    var claudeInstalled: Bool = false
    var codexInstalled: Bool = false
    var notes: [String] = []
}

extension HookInstaller {
    static let claudeEvents: [(name: String, timeout: Int)] = [
        ("UserPromptSubmit", 5),
        ("PreToolUse", 5),
        ("PostToolUse", 5),
        ("Notification", 86400),
        ("Stop", 5),
        ("SubagentStart", 5),
        ("SubagentStop", 5),
        ("SessionStart", 5),
        ("SessionEnd", 5),
    ]

    static func installClaudeHooks(into report: inout InstallReport) {
        guard report.bridgeInstalled else { return }
        let command = "\"\(bridgePath.path)\" --source claude"
        do {
            try writeManagedHooks(
                settingsURL: claudeSettings,
                events: claudeEvents,
                command: command,
                format: .claude
            )
            report.claudeInstalled = true
        } catch {
            report.notes.append("[claude] install failed: \(error.localizedDescription)")
        }
    }

    static func uninstallClaudeHooks(into report: inout InstallReport) {
        try? removeManagedHooks(settingsURL: claudeSettings)
    }
}

extension HookInstaller {
    static let codexEvents: [(name: String, timeout: Int)] = [
        ("SessionStart", 5),
        ("SessionEnd", 5),
        ("UserPromptSubmit", 5),
        ("PreToolUse", 5),
        ("PostToolUse", 5),
        ("PermissionRequest", 86400),
        ("Stop", 5),
    ]

    static func installCodexHooks(into report: inout InstallReport) {
        guard report.bridgeInstalled else { return }
        let command = "\"\(bridgePath.path)\" --source codex"
        do {
            try writeManagedHooks(
                settingsURL: codexHooks,
                events: codexEvents,
                command: command,
                format: .nested
            )
            try? enableCodexHooksInConfigToml()
            report.codexInstalled = true
        } catch {
            report.notes.append("[codex] install failed: \(error.localizedDescription)")
        }
    }

    static func uninstallCodexHooks(into report: inout InstallReport) {
        try? removeManagedHooks(settingsURL: codexHooks)
        try? removeManagedFromCodexConfigToml()
    }

    private static func enableCodexHooksInConfigToml() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: codexConfigToml.path) else { return }
        let original = (try? String(contentsOf: codexConfigToml, encoding: .utf8)) ?? ""
        if original.contains("hooks = true") || original.contains("hooks=true") { return }

        let appended: String
        if original.hasSuffix("\n") || original.isEmpty {
            appended = original + "\n# tokenisland-managed\nhooks = true\n"
        } else {
            appended = original + "\n\n# tokenisland-managed\nhooks = true\n"
        }
        try appended.data(using: .utf8)?.write(to: codexConfigToml)
    }

    private static func removeManagedFromCodexConfigToml() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: codexConfigToml.path) else { return }
        let original = (try? String(contentsOf: codexConfigToml, encoding: .utf8)) ?? ""
        let lines = original.components(separatedBy: "\n")
        var output: [String] = []
        var skipNext = false
        for line in lines {
            if skipNext {
                skipNext = false
                continue
            }
            if line.trimmingCharacters(in: .whitespaces) == "# tokenisland-managed" {
                skipNext = true
                continue
            }
            output.append(line)
        }
        while output.last?.isEmpty == true { output.removeLast() }
        let cleaned = output.joined(separator: "\n") + "\n"
        if cleaned != original {
            try cleaned.data(using: .utf8)?.write(to: codexConfigToml)
        }
    }
}

extension HookInstaller {
    enum HookFormat {
        case claude
        case nested
    }

    static func writeManagedHooks(
        settingsURL: URL,
        events: [(name: String, timeout: Int)],
        command: String,
        format: HookFormat
    ) throws {
        let fm = FileManager.default
        let parentDir = settingsURL.deletingLastPathComponent()
        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = obj
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for (event, _) in events { hooks = removeManagedFromEvent(hooks, event: event) }

        for (event, timeout) in events {
            let entry: [String: Any]
            switch format {
            case .claude:
                entry = [
                    "matcher": "",
                    "_managedBy": managedTag,
                    "hooks": [[
                        "type": "command",
                        "command": command,
                        "timeout": timeout,
                    ] as [String: Any]],
                ]
            case .nested:
                entry = [
                    "_managedBy": managedTag,
                    "hooks": [[
                        "type": "command",
                        "command": command,
                        "timeout": timeout,
                    ] as [String: Any]],
                ]
            }
            var arr = hooks[event] as? [[String: Any]] ?? []
            arr.append(entry)
            hooks[event] = arr
        }
        root["hooks"] = hooks

        let pretty: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        let data = try JSONSerialization.data(withJSONObject: root, options: pretty)
        try data.write(to: settingsURL, options: .atomic)
    }

    static func removeManagedFromEvent(_ hooks: [String: Any], event: String) -> [String: Any] {
        guard var arr = hooks[event] as? [[String: Any]] else { return hooks }
        arr.removeAll { ($0["_managedBy"] as? String) == managedTag }
        var copy = hooks
        if arr.isEmpty { copy.removeValue(forKey: event) } else { copy[event] = arr }
        return copy
    }

    static func removeManagedHooks(settingsURL: URL) throws {
        guard let data = try? Data(contentsOf: settingsURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        guard var hooks = root["hooks"] as? [String: Any] else { return }
        let events = hooks.keys
        for event in events {
            hooks = removeManagedFromEvent(hooks, event: event)
        }
        if hooks.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = hooks }

        let pretty: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        let out = try JSONSerialization.data(withJSONObject: root, options: pretty)
        try out.write(to: settingsURL, options: .atomic)
    }

    static func isInstalled(for source: AgentSource) -> Bool {
        let url: URL = (source == .claude) ? claudeSettings : codexHooks
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any]
        else { return false }
        for (_, value) in hooks {
            guard let arr = value as? [[String: Any]] else { continue }
            if arr.contains(where: { ($0["_managedBy"] as? String) == managedTag }) {
                return true
            }
        }
        return false
    }
}
