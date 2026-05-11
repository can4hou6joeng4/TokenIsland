import AppKit
import SwiftUI
import TokenIslandCore

struct NotchPanelView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var tokenStore: TokenUsageStore
    let geometry: NotchGeometry
    var onHoverChange: (Bool) -> Void = { _ in }

    @State private var isHovering = false

    private var hasPending: Bool { appState.hasPendingInteraction }
    private var isExpanded: Bool { isHovering || hasPending }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .frame(height: geometry.notchHeight)
            if isExpanded {
                Line()
                    .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
                expandedContent
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .background(
            NotchPanelShape()
                .fill(Color.black)
        )
        .clipShape(NotchPanelShape())
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        .contentShape(NotchPanelShape())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
            onHoverChange(hovering || hasPending)
        }
        .onChange(of: hasPending) { _, pending in
            if pending { onHoverChange(true) }
        }
        .animation(.easeInOut(duration: 0.20), value: isExpanded)
        .animation(.easeInOut(duration: 0.20), value: appState.sessions.map(\.id))
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            leftWing
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            if geometry.hasNotch {
                Spacer(minLength: geometry.notchWidth)
            }
            rightWing
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
        }
    }

    private var leftWing: some View {
        HStack(spacing: 8) {
            statusGlyph
            Text(headerText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var rightWing: some View {
        HStack(spacing: 8) {
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
                .opacity(active ? 1.0 : 0.65)
            if tokenStore.isLoading && value == 0 {
                Text("…")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, alignment: .leading)
            } else {
                Text(formatTokens(value))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(active ? 1.0 : 0.78))
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var statusGlyph: some View {
        ZStack {
            if tokenStore.isLoading && appState.sessions.isEmpty {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.55)
                    .frame(width: 18, height: 18)
            } else {
                Circle().fill(statusColor.opacity(0.20)).frame(width: 18, height: 18)
                Circle().fill(statusColor).frame(width: 8, height: 8)
            }
        }
        .shadow(color: statusColor.opacity(0.55), radius: 3)
    }

    private var statusColor: Color {
        if hasPending { return .yellow }
        if appState.activeSessionCount > 0 { return .green }
        return Color.gray.opacity(0.55)
    }

    private var headerText: String {
        if hasPending { return "Action needed" }
        if tokenStore.isLoading && appState.sessions.isEmpty { return "Loading…" }
        let n = appState.activeSessionCount
        if n > 0 { return "\(n) running" }
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
        .fixedSize(horizontal: false, vertical: true)
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
                .fill(Color.white.opacity(0.05))
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

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
