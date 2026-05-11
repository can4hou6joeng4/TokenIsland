import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private var window: NSPanel?
    private let appState: AppState
    private let tokenStore: TokenUsageStore
    private var hostingView: NSHostingView<NotchPanelView>?
    private var currentGeom: NotchGeometry = .default
    private var isExpanded: Bool = false

    private let expandedHeight: CGFloat = 280

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

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth(geom: geom, screen: screen), height: geom.notchHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true

        let rootView = NotchPanelView(
            appState: appState,
            tokenStore: tokenStore,
            geometry: geom,
            onHoverChange: { [weak self] expand in
                Task { @MainActor [weak self] in
                    self?.setExpanded(expand)
                }
            }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting
        hostingView = hosting

        positionAtNotch(panel: panel, geom: geom, screen: screen, height: geom.notchHeight, animate: false)
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
                let rv = NotchPanelView(
                    appState: self.appState,
                    tokenStore: self.tokenStore,
                    geometry: g,
                    onHoverChange: { [weak self] expand in
                        Task { @MainActor [weak self] in self?.setExpanded(expand) }
                    }
                )
                self.hostingView?.rootView = rv
                let h = self.isExpanded ? self.expandedHeight : g.notchHeight
                self.positionAtNotch(panel: w, geom: g, screen: s, height: h, animate: false)
            }
        }
    }

    func hide() { window?.orderOut(nil) }

    private func setExpanded(_ expand: Bool) {
        guard isExpanded != expand else { return }
        isExpanded = expand
        guard let panel = window, let screen = NSScreen.main else { return }
        let h = expand ? expandedHeight : currentGeom.notchHeight
        positionAtNotch(panel: panel, geom: currentGeom, screen: screen, height: h, animate: true)
    }

    private func panelWidth(geom: NotchGeometry, screen: NSScreen) -> CGFloat {
        let wingWidth: CGFloat = 150
        let total = geom.notchWidth + wingWidth * 2
        return min(total, screen.frame.width - 40)
    }

    private func positionAtNotch(panel: NSPanel, geom: NotchGeometry, screen: NSScreen, height: CGFloat, animate: Bool) {
        let screenFrame = screen.frame
        let width = panelWidth(geom: geom, screen: screen)
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: animate)
    }
}
