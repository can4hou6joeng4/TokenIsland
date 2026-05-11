import AppKit
import Foundation

@main
enum TokenIslandLaunch {
    static func main() {
        let argv = CommandLine.arguments
        if argv.count >= 2 {
            switch argv[1] {
            case "install":
                MainActor.assumeIsolated { runInstall() }
                return
            case "uninstall":
                MainActor.assumeIsolated { runUninstall() }
                return
            case "doctor":
                MainActor.assumeIsolated { runDoctor() }
                return
            case "--help", "-h", "help":
                printHelp()
                return
            default:
                break
            }
        }

        MainActor.assumeIsolated {
            let delegate = AppDelegate()
            let app = NSApplication.shared
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }

    @MainActor private static func runInstall() {
        let report = HookInstaller.installAll()
        print("bridge:  \(report.bridgeInstalled ? "OK" : "FAIL")")
        print("claude:  \(report.claudeInstalled ? "OK" : "skip / FAIL")")
        print("codex:   \(report.codexInstalled ? "OK" : "skip / FAIL")")
        for note in report.notes { print(note) }
    }

    @MainActor private static func runUninstall() {
        _ = HookInstaller.uninstallAll()
        print("uninstalled")
    }

    @MainActor private static func runDoctor() {
        print("TokenIsland doctor")
        print("  socket path:        \(TokenIslandCore_socketPath())")
        print("  install dir:        \(HookInstaller.installDir.path)")
        print("  bridge present:     \(FileManager.default.isExecutableFile(atPath: HookInstaller.bridgePath.path))")
        print("  claude hook on:     \(HookInstaller.isInstalled(for: .claude))")
        print("  codex hook on:      \(HookInstaller.isInstalled(for: .codex))")
        print("  ~/.claude exists:   \(FileManager.default.fileExists(atPath: HookInstaller.claudeSettings.deletingLastPathComponent().path))")
        print("  ~/.codex exists:    \(FileManager.default.fileExists(atPath: HookInstaller.codexHome.path))")
    }

    private static func printHelp() {
        print("""
        TokenIsland — notch panel for Claude Code & Codex CLI

        Usage:
          TokenIsland             launch the notch panel (no side effects)
          TokenIsland install     install hooks into ~/.claude and ~/.codex
          TokenIsland uninstall   remove all tokenisland-managed hooks
          TokenIsland doctor      print install state and paths
          TokenIsland help        this message
        """)
    }
}

import TokenIslandCore
private func TokenIslandCore_socketPath() -> String { TokenIslandCore.socketPath }
