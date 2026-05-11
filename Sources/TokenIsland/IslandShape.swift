import SwiftUI
import TokenIslandCore

struct NotchCapsule: Shape {
    var topInset: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 18
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + topInset))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + topInset))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topInset))
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
