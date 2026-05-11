import SwiftUI
import TokenIslandCore

struct NotchPanelShape: Shape {
    var bottomRadius: CGFloat = 22
    var minHeight: CGFloat = 38

    func path(in rect: CGRect) -> Path {
        let maxY = max(rect.maxY, rect.minY + minHeight)
        let br = min(bottomRadius, rect.width / 4, (maxY - rect.minY) / 2)
        let k: CGFloat = 0.62

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: maxY - br))
        p.addCurve(
            to: CGPoint(x: rect.maxX - br, y: maxY),
            control1: CGPoint(x: rect.maxX, y: maxY - br * (1 - k)),
            control2: CGPoint(x: rect.maxX - br * (1 - k), y: maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + br, y: maxY))
        p.addCurve(
            to: CGPoint(x: rect.minX, y: maxY - br),
            control1: CGPoint(x: rect.minX + br * (1 - k), y: maxY),
            control2: CGPoint(x: rect.minX, y: maxY - br * (1 - k))
        )
        p.closeSubpath()
        return p
    }
}

enum AgentPalette {
    static func base(_ source: AgentSource) -> Color {
        switch source {
        case .claude: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .codex: return Color(red: 0.30, green: 0.80, blue: 0.55)
        }
    }
    static func gradient(_ source: AgentSource) -> LinearGradient {
        let c = base(source)
        return LinearGradient(
            colors: [c.opacity(0.95), c.opacity(0.70)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    static func glyph(_ source: AgentSource) -> String {
        switch source {
        case .claude: return "sparkle"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct NotchGeometry: Equatable {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var hasNotch: Bool { notchHeight > 5 }

    static let `default` = NotchGeometry(notchWidth: 200, notchHeight: 38)

    static func resolve(for screen: NSScreen) -> NotchGeometry {
        let top = screen.safeAreaInsets.top
        if top > 5 {
            return NotchGeometry(notchWidth: 200, notchHeight: top)
        }
        return NotchGeometry(notchWidth: 0, notchHeight: 28)
    }
}
