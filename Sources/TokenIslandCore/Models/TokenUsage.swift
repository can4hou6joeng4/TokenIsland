import Foundation

public enum AgentSource: String, Codable, Sendable, CaseIterable {
    case claude
    case codex

    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        }
    }
}

public enum TokenMode: String, Codable, Sendable {
    case billable
    case raw
}

public struct TokenCounts: Codable, Sendable, Equatable {
    public var raw: Int
    public var billable: Int

    public init(raw: Int = 0, billable: Int = 0) {
        self.raw = raw
        self.billable = billable
    }

    public static func + (lhs: TokenCounts, rhs: TokenCounts) -> TokenCounts {
        TokenCounts(raw: lhs.raw + rhs.raw, billable: lhs.billable + rhs.billable)
    }

    public static func += (lhs: inout TokenCounts, rhs: TokenCounts) {
        lhs = lhs + rhs
    }

    public func value(for mode: TokenMode) -> Int {
        mode == .billable ? billable : raw
    }
}

public struct BucketKey: Hashable, Codable, Sendable {
    public let dateString: String

    public init(dateString: String) {
        self.dateString = dateString
    }

    public init(date: Date, calendar: Calendar = .iso8601LocalCalendar) {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        self.dateString = String(format: "%04d-%02d-%02d", y, m, d)
    }
}

public extension Calendar {
    static let iso8601LocalCalendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone.current
        return c
    }()
}

public struct TokenSnapshot: Codable, Sendable {
    public var perBucket: [BucketKey: [String: TokenCounts]]

    public init(perBucket: [BucketKey: [String: TokenCounts]] = [:]) {
        self.perBucket = perBucket
    }

    public mutating func bump(bucket: BucketKey, model: String, counts: TokenCounts) {
        var modelMap = perBucket[bucket] ?? [:]
        modelMap[model, default: TokenCounts()] += counts
        perBucket[bucket] = modelMap
    }

    public func total(mode: TokenMode) -> Int {
        perBucket.values.flatMap { $0.values }.reduce(0) { $0 + $1.value(for: mode) }
    }

    public func total(for bucket: BucketKey, mode: TokenMode) -> Int {
        perBucket[bucket]?.values.reduce(0) { $0 + $1.value(for: mode) } ?? 0
    }
}

public extension TokenSnapshot {
    func today(mode: TokenMode = .billable, now: Date = Date()) -> Int {
        let key = BucketKey(date: now)
        guard let map = perBucket[key] else { return 0 }
        return map.values.reduce(0) { $0 + $1.value(for: mode) }
    }

    func lastNDays(_ n: Int, mode: TokenMode = .billable, now: Date = Date()) -> [(BucketKey, Int)] {
        let cal = Calendar.iso8601LocalCalendar
        var out: [(BucketKey, Int)] = []
        for offset in (0..<n).reversed() {
            guard let date = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = BucketKey(date: date)
            let val = perBucket[key]?.values.reduce(0) { $0 + $1.value(for: mode) } ?? 0
            out.append((key, val))
        }
        return out
    }
}
