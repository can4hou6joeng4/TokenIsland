import SwiftUI
import TokenIslandCore

struct AgentRowView: View {
    let source: AgentSource
    let session: SessionInfo?
    let tokensToday: Int
    let last7Days: [(BucketKey, Int)]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            agentAvatar
            VStack(alignment: .leading, spacing: 3) {
                titleLine
                subtitleLine
                if !last7Days.isEmpty {
                    sparkline
                        .frame(height: 14)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 6)
            tokenColumn
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var agentAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AgentPalette.gradient(source))
                .frame(width: 28, height: 28)
            Image(systemName: AgentPalette.glyph(source))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .overlay(alignment: .topTrailing) {
            statusDot
                .offset(x: 4, y: -3)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
            .shadow(color: statusColor.opacity(0.55), radius: 3)
    }

    private var statusColor: Color {
        guard let s = session else { return Color.gray.opacity(0.5) }
        switch s.status {
        case .running: return .green
        case .waitingForPermission, .waitingForAnswer: return .yellow
        case .error: return .red
        case .finished, .idle: return Color.gray.opacity(0.55)
        }
    }

    private var titleLine: some View {
        HStack(spacing: 6) {
            Text(source.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            if session?.status == .running, let tool = session?.lastToolName {
                Text("· \(tool)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
    }

    private var subtitleLine: some View {
        Text(subtitleText)
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.5))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var subtitleText: String {
        guard let s = session else { return "no recent session" }
        switch s.status {
        case .running: return "running" + (s.cwd.map { " · \(folderName($0))" } ?? "")
        case .waitingForPermission: return "waiting for permission"
        case .waitingForAnswer: return s.pendingPrompt ?? "waiting for answer"
        case .error: return "error"
        case .finished: return "finished " + relativeTime(s.lastEventAt)
        case .idle: return "idle"
        }
    }

    private func folderName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var tokenColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatTokens(tokensToday))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text("today")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }

    private var sparkline: some View {
        GeometryReader { geo in
            let values = last7Days.map { Double($0.1) }
            let maxV = max(values.max() ?? 1, 1)
            let barWidth = max((geo.size.width - 6) / CGFloat(values.count) - 2, 2)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(AgentPalette.base(source).opacity(v == 0 ? 0.18 : 0.85))
                        .frame(width: barWidth, height: max(CGFloat(v / maxV) * geo.size.height, 1.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
