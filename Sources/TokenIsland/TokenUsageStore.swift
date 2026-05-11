import Combine
import Foundation
import TokenIslandCore

@MainActor
final class TokenUsageStore: ObservableObject {
    @Published private(set) var aggregated: AggregatedUsage = AggregatedUsage()
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastRefreshed: Date?

    private let scanner: TokenUsageScanner
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?

    var mode: TokenMode = .billable

    init(scanner: TokenUsageScanner = TokenUsageScanner()) {
        self.scanner = scanner
    }

    func startBackgroundSampling(refreshInterval: TimeInterval = 60) {
        refreshNow()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshNow() }
        }
    }

    func stopBackgroundSampling() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
    }

    func refreshNow() {
        refreshTask?.cancel()
        isLoading = true
        let scanner = self.scanner
        refreshTask = Task.detached(priority: .utility) {
            let weekAgo = Calendar.iso8601LocalCalendar.date(byAdding: .day, value: -30, to: Date())
            let claude = scanner.scanClaude(since: weekAgo)
            let codex = scanner.scanCodex(since: weekAgo)
            await MainActor.run {
                self.aggregated = AggregatedUsage(claude: claude, codex: codex)
                self.lastRefreshed = Date()
                self.isLoading = false
            }
        }
    }

    var todayClaude: Int { aggregated.claude.today(mode: mode) }
    var todayCodex: Int { aggregated.codex.today(mode: mode) }
    var todayTotal: Int { todayClaude + todayCodex }

    func last7DaysCombined() -> [(BucketKey, Int)] {
        let claude = aggregated.claude.lastNDays(7, mode: mode)
        let codex = aggregated.codex.lastNDays(7, mode: mode)
        return zip(claude, codex).map { (a, b) in (a.0, a.1 + b.1) }
    }

    func last7Days(source: AgentSource) -> [(BucketKey, Int)] {
        switch source {
        case .claude: return aggregated.claude.lastNDays(7, mode: mode)
        case .codex: return aggregated.codex.lastNDays(7, mode: mode)
        }
    }
}
