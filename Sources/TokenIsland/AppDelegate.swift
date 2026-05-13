import AppKit
import Sparkle
import SwiftUI
import TokenIslandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelWindowController?
    private var hookServer: HookServer?
    private let appState = AppState()
    private let tokenStore = TokenUsageStore()
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = PanelWindowController(appState: appState, tokenStore: tokenStore)
        panelController?.show()

        let server = HookServer { [weak appState] event in
            Task { @MainActor [weak appState] in
                appState?.apply(event)
            }
        }
        server.start()
        hookServer = server

        tokenStore.startBackgroundSampling()

        if SparkleConfiguration.shouldStartUpdater() {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hookServer?.stop()
        tokenStore.stopBackgroundSampling()
    }
}
