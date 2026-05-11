import AppKit
import SwiftUI
import TokenIslandCore

struct NotchPanelView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var tokenStore: TokenUsageStore

    @State private var isHovering = false

    private var hasPending: Bool { appState.hasPendingInteraction }
    private var isExpanded: Bool { isHovering || hasPending }

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
            if isExpanded {
                Divider()
                    .frame(height: 0.5)
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 8)
                expandedContent
            }
        }
        .background(
            NotchCapsule(topInset: 0)
                .fill(Color.black.opacity(0.92))
        )
        .clipShape(NotchCapsule(topInset: 0))
        .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: appState.sessions.map(\.id))
    }

    private var collapsedBar: some View {
        HStack(spacing: 10) {
            leftWing
            Spacer(minLength: 24)
            rightWing
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(height: 38)
    }

    private var leftWing: some View {
        HStack(spacing: 8) {
            statusGlyph
            Text(headerText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    private var rightWing: some View {
        HStack(spacing: 6) {
            agentPill(.claude, value: tokenStore.todayClaude)
            agentPill(.codex, value: tokenStore.todayCodex)
        }
    }

    private func agentPill(_ source: AgentSource, value: Int) -> some View {
        let active = appState.sessions.contains { $0.source == source && $0.status != .idle && $0.status != .finished }
        return HStack(spacing: 4) {
            Circle()
                .fill(AgentPalette.base(source))
                .frame(width: 6, height: 6)
                .opacity(active ? 1.0 : 0.55)
            Text(formatTokens(value))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(active ? 1.0 : 0.75))
                .monospacedDigit()
        }
    }

    private var statusGlyph: some View {
        ZStack {
            Circle().fill(statusColor.opacity(0.18)).frame(width: 18, height: 18)
            Circle().fill(statusColor).frame(width: 8, height: 8)
        }
        .shadow(color: statusColor.opacity(0.6), radius: 4)
    }

    private var statusColor: Color {
        if hasPending { return .yellow }
        if appState.activeSessionCount > 0 { return .green }
        return Color.gray.opacity(0.6)
    }

    private var headerText: String {
        if hasPending { return "Action needed" }
        let n = appState.activeSessionCount
        if n > 0 { return "\(n) session\(n > 1 ? "s" : "")" }
        return "TokenIsland"
    }

    private var expandedContent: some View {
        VStack(spacing: 8) {
            ForEach(AgentSource.allCases, id: \.self) { source in
                AgentRowView(
                    source: source,
                    session: latestSession(for: source),
                    tokensToday: tokens(for: source),
                    last7Days: tokenStore.last7Days(source: source)
                )
            }
            todayFooter
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func latestSession(for source: AgentSource) -> SessionInfo? {
        appState.sessions.first { $0.source == source }
    }

    private func tokens(for source: AgentSource) -> Int {
        switch source {
        case .claude: return tokenStore.todayClaude
        case .codex: return tokenStore.todayCodex
        }
    }

    private var todayFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            Text("Today total")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text(formatTokens(tokenStore.todayTotal))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            if let last = tokenStore.lastRefreshed {
                Text(refreshAge(last))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.30))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        )
    }

    private func refreshAge(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "\(secs)s ago" }
        return "\(secs / 60)m ago"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
