import AppKit
import SwiftUI
import TokenIslandCore

struct NotchPanelView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var tokenStore: TokenUsageStore

    var body: some View {
        VStack(spacing: 0) {
            islandHeader
            if appState.isPanelExpanded {
                sessionsList
                Divider().background(Color.white.opacity(0.15))
                usageRow
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.22)) {
                appState.isPanelExpanded = hovering || appState.hasPendingInteraction
            }
        }
    }

    private var islandHeader: some View {
        HStack(spacing: 8) {
            statusDot
            Text(headerTitle)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 0)
            if !appState.isPanelExpanded {
                Text(compactUsage)
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minWidth: 220, idealWidth: 280)
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(appState.sessions) { session in
                sessionRow(session)
            }
            if appState.sessions.isEmpty {
                Text("No active sessions")
                    .foregroundColor(.white.opacity(0.45))
                    .font(.system(size: 11, design: .rounded))
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionRow(_ session: SessionInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: session.source == .claude ? "c.circle.fill" : "x.circle.fill")
                .foregroundColor(session.source == .claude ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title ?? session.source.displayName)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .medium))
                Text(statusLine(session))
                    .foregroundColor(.white.opacity(0.55))
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var usageRow: some View {
        HStack(spacing: 8) {
            usagePill(label: "Claude", value: tokenStore.todayClaude, color: .orange)
            usagePill(label: "Codex", value: tokenStore.todayCodex, color: .green)
            Spacer()
            Text("Today")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 10, weight: .regular, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }

    private func usagePill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundColor(.white.opacity(0.7)).font(.system(size: 10))
            Text(formatTokens(value))
                .foregroundColor(.white)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
    }

    private var compactUsage: String {
        formatTokens(tokenStore.todayTotal) + " today"
    }

    private var headerTitle: String {
        if appState.hasPendingInteraction { return "Action needed" }
        if appState.activeSessionCount > 0 {
            return "\(appState.activeSessionCount) session\(appState.activeSessionCount > 1 ? "s" : "") running"
        }
        return "TokenIsland"
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .shadow(color: statusColor.opacity(0.6), radius: 4)
    }

    private var statusColor: Color {
        if appState.hasPendingInteraction { return .yellow }
        if appState.activeSessionCount > 0 { return .green }
        return .gray
    }

    private func statusLine(_ session: SessionInfo) -> String {
        switch session.status {
        case .running:
            if let tool = session.lastToolName { return "running · \(tool)" }
            return "running"
        case .waitingForPermission:
            return "waiting for permission"
        case .waitingForAnswer:
            return session.pendingPrompt ?? "waiting for answer"
        case .error: return "error"
        case .finished: return "finished"
        case .idle: return "idle"
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        }
        if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}
