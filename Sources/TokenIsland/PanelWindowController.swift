import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private var window: NSPanel?
    private let appState: AppState
    private let tokenStore: TokenUsageStore
    private var hostingView: NSHostingView<NotchPanelView>?
    private var currentGeom: NotchGeometry = .default

    private let fixedPanelHeight: CGFloat = 320

    init(appState: AppState, tokenStore: TokenUsageStore) {
        self.appState = appState
        self.tokenStore = tokenStore
    }

    func show() {
        guard window == nil else {
            window?.orderFrontRegardless()
            return
        }
        guard let screen = NSScreen.main else { return }
        let geom = NotchGeometry.resolve(for: screen)
        currentGeom = geom

        let width = panelWidth(geom: geom, screen: screen)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: fixedPanelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true

        let rootView = NotchPanelView(
            appState: appState,
            tokenStore: tokenStore,
            geometry: geom
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting
        hostingView = hosting

        position(panel: panel, geom: geom, screen: screen)
        panel.orderFrontRegardless()
        window = panel

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let w = self.window, let s = NSScreen.main else { return }
                let g = NotchGeometry.resolve(for: s)
                self.currentGeom = g
                self.hostingView?.rootView = NotchPanelView(
                    appState: self.appState,
                    tokenStore: self.tokenStore,
                    geometry: g
                )
                self.position(panel: w, geom: g, screen: s)
            }
        }
    }

    func hide() { window?.orderOut(nil) }

    private func panelWidth(geom: NotchGeometry, screen: NSScreen) -> CGFloat {
        let wingWidth: CGFloat = 150
        let total = geom.notchWidth + wingWidth * 2
        return min(total, screen.frame.width - 40)
    }

    private func position(panel: NSPanel, geom: NotchGeometry, screen: NSScreen) {
        let screenFrame = screen.frame
        let width = panelWidth(geom: geom, screen: screen)
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - fixedPanelHeight
        panel.setFrame(NSRect(x: x, y: y, width: width, height: fixedPanelHeight), display: true, animate: false)
    }
}
