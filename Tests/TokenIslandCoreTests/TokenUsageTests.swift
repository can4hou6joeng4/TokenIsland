import XCTest
@testable import TokenIslandCore

final class TokenUsageTests: XCTestCase {

    func testTokenCountsAddition() {
        var a = TokenCounts(raw: 10, billable: 8)
        let b = TokenCounts(raw: 5, billable: 4)
        a += b
        XCTAssertEqual(a.raw, 15)
        XCTAssertEqual(a.billable, 12)
    }

    func testTokenCountsModeSwitch() {
        let c = TokenCounts(raw: 100, billable: 30)
        XCTAssertEqual(c.value(for: .raw), 100)
        XCTAssertEqual(c.value(for: .billable), 30)
    }

    func testBucketKeyFromISO8601() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: "2026-05-11T12:34:56.789Z") else {
            XCTFail("could not parse fixture date")
            return
        }
        let key = BucketKey(date: date)
        XCTAssertEqual(key.dateString.count, 10)
        XCTAssertTrue(key.dateString.hasPrefix("2026-"))
    }

    func testSnapshotBumpAggregates() {
        var snap = TokenSnapshot()
        let key = BucketKey(dateString: "2026-05-11")
        snap.bump(bucket: key, model: "claude-opus-4-7", counts: TokenCounts(raw: 100, billable: 80))
        snap.bump(bucket: key, model: "claude-opus-4-7", counts: TokenCounts(raw: 50, billable: 40))
        snap.bump(bucket: key, model: "gpt-5", counts: TokenCounts(raw: 20, billable: 20))

        XCTAssertEqual(snap.perBucket[key]?["claude-opus-4-7"]?.raw, 150)
        XCTAssertEqual(snap.perBucket[key]?["claude-opus-4-7"]?.billable, 120)
        XCTAssertEqual(snap.perBucket[key]?["gpt-5"]?.raw, 20)
        XCTAssertEqual(snap.total(for: key, mode: .billable), 140)
        XCTAssertEqual(snap.total(for: key, mode: .raw), 170)
    }

    func testLastNDaysReturnsOldestToNewest() {
        var snap = TokenSnapshot()
        let cal = Calendar.iso8601LocalCalendar
        let now = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        snap.bump(bucket: BucketKey(date: now), model: "m", counts: TokenCounts(raw: 10, billable: 10))
        snap.bump(bucket: BucketKey(date: yesterday), model: "m", counts: TokenCounts(raw: 5, billable: 5))

        let result = snap.lastNDays(3, now: now)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.last?.1, 10, "today should be last in chronological order")
        XCTAssertEqual(result.first?.1, 0, "two days ago should be zero")
    }
}
