import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private var window: NSPanel?
    private let appState: AppState
    private let tokenStore: TokenUsageStore

    init(appState: AppState, tokenStore: TokenUsageStore) {
        self.appState = appState
        self.tokenStore = tokenStore
    }

    func show() {
        guard window == nil else {
            window?.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false

        let hosting = NSHostingView(
            rootView: NotchPanelView(appState: appState, tokenStore: tokenStore)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting

        positionAtNotch(panel: panel)
        panel.orderFrontRegardless()
        window = panel

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let w = self.window else { return }
                self.positionAtNotch(panel: w)
            }
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func positionAtNotch(panel: NSPanel) {
        guard let screen = NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let safeArea = screen.safeAreaInsets
        let topInset = safeArea.top

        let panelSize = panel.contentView?.fittingSize ?? NSSize(width: 320, height: 36)
        let width: CGFloat = max(280, panelSize.width)
        let height: CGFloat = max(36, panelSize.height)

        let x = screenFrame.midX - width / 2
        let y: CGFloat
        if topInset > 0 {
            y = screenFrame.maxY - topInset / 2 - height / 2
        } else {
            y = screenFrame.maxY - height - 4
        }

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
