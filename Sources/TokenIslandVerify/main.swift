import Foundation
import TokenIslandCore

let scanner = TokenUsageScanner()
let cal = Calendar.iso8601LocalCalendar
let weekAgo = cal.date(byAdding: .day, value: -7, to: Date())

print("Scanning Claude jsonl (~/.claude/projects)...")
let claudeStart = Date()
let claude = scanner.scanClaude(since: weekAgo)
let claudeElapsed = Date().timeIntervalSince(claudeStart)

print("Scanning Codex jsonl (~/.codex)...")
let codexStart = Date()
let codex = scanner.scanCodex(since: weekAgo)
let codexElapsed = Date().timeIntervalSince(codexStart)

func bigNumber(_ n: Int) -> String {
    let nf = NumberFormatter()
    nf.numberStyle = .decimal
    return nf.string(from: NSNumber(value: n)) ?? "\(n)"
}

print("")
print("=== Claude (last 7 days, billable) ===")
print("Buckets parsed: \(claude.perBucket.count)  |  scan time: \(String(format: "%.2f", claudeElapsed))s")
let claudeWeek = claude.lastNDays(7)
for (bucket, total) in claudeWeek {
    print("  \(bucket.dateString)  \(bigNumber(total))")
}
print("  Today total: \(bigNumber(claude.today()))")
print("  7d  total: \(bigNumber(claudeWeek.reduce(0) { $0 + $1.1 }))")

print("")
print("=== Codex (last 7 days, billable) ===")
print("Buckets parsed: \(codex.perBucket.count)  |  scan time: \(String(format: "%.2f", codexElapsed))s")
let codexWeek = codex.lastNDays(7)
for (bucket, total) in codexWeek {
    print("  \(bucket.dateString)  \(bigNumber(total))")
}
print("  Today total: \(bigNumber(codex.today()))")
print("  7d  total: \(bigNumber(codexWeek.reduce(0) { $0 + $1.1 }))")

print("")
print("=== Models seen ===")
let claudeModels = Set(claude.perBucket.values.flatMap { $0.keys })
let codexModels = Set(codex.perBucket.values.flatMap { $0.keys })
print("Claude: \(claudeModels.sorted().joined(separator: ", "))")
print("Codex:  \(codexModels.sorted().joined(separator: ", "))")
