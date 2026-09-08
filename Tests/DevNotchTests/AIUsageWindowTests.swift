import XCTest
@testable import DevNotch

final class AIUsageWindowTests: XCTestCase {
    func testWindowDurationLabel() {
        // 5 hours
        let w300 = AIUsageWindow(usedPercent: 28, windowDurationMins: 300, resetsAt: nil)
        XCTAssertEqual(w300.label, "5 Hour")

        // 1 week (7 days)
        let wWeekly = AIUsageWindow(usedPercent: 16, windowDurationMins: 10080, resetsAt: nil)
        XCTAssertEqual(wWeekly.label, "Weekly")

        // 24 hours / daily
        let wDaily = AIUsageWindow(usedPercent: 50, windowDurationMins: 1440, resetsAt: nil)
        XCTAssertEqual(wDaily.label, "Daily")

        // 1 hour
        let w1h = AIUsageWindow(usedPercent: 10, windowDurationMins: 60, resetsAt: nil)
        XCTAssertEqual(w1h.label, "1 Hour")

        // Arbitrary multiple of days (e.g. 3 days = 4320 mins)
        let w3d = AIUsageWindow(usedPercent: 10, windowDurationMins: 4320, resetsAt: nil)
        XCTAssertEqual(w3d.label, "3 Day")

        // Arbitrary multiple of hours (e.g. 2 hours = 120 mins)
        let w2h = AIUsageWindow(usedPercent: 10, windowDurationMins: 120, resetsAt: nil)
        XCTAssertEqual(w2h.label, "2 Hour")

        // Arbitrary minutes (e.g. 45 mins)
        let w45m = AIUsageWindow(usedPercent: 10, windowDurationMins: 45, resetsAt: nil)
        XCTAssertEqual(w45m.label, "45m")
    }

    func testRemainingPercentCalculation() {
        // Normal 28% used -> 72% remaining
        let w28 = AIUsageWindow(usedPercent: 28.0, windowDurationMins: 300, resetsAt: nil)
        XCTAssertEqual(w28.remainingPercent, 72.0)

        // 100% used -> 0% remaining
        let w100 = AIUsageWindow(usedPercent: 100.0, windowDurationMins: 300, resetsAt: nil)
        XCTAssertEqual(w100.remainingPercent, 0.0)

        // 0% used -> 100% remaining
        let w0 = AIUsageWindow(usedPercent: 0.0, windowDurationMins: 300, resetsAt: nil)
        XCTAssertEqual(w0.remainingPercent, 100.0)

        // Clamping overflow (>100% used)
        let wOver = AIUsageWindow(usedPercent: 120.0, windowDurationMins: 300, resetsAt: nil)
        XCTAssertEqual(wOver.remainingPercent, 0.0)

        // Clamping underflow (<0% used)
        let wUnder = AIUsageWindow(usedPercent: -10.0, windowDurationMins: 300, resetsAt: nil)
        XCTAssertEqual(wUnder.remainingPercent, 100.0)
    }

    func testResetTimeRemaining() {
        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // 2 hours 14 minutes in future (134 minutes = 8040 seconds)
        let futureDate = baseDate.addingTimeInterval(8040)
        let window = AIUsageWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: futureDate)

        let remainingStr = window.resetTimeRemaining(relativeTo: baseDate)
        XCTAssertEqual(remainingStr, "Reset in 2h 14m")

        // 45 minutes in future (2700 seconds)
        let future45m = baseDate.addingTimeInterval(2700)
        let window45m = AIUsageWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: future45m)
        XCTAssertEqual(window45m.resetTimeRemaining(relativeTo: baseDate), "Reset in 45m")

        // Past date
        let pastDate = baseDate.addingTimeInterval(-100)
        let windowPast = AIUsageWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: pastDate)
        XCTAssertEqual(windowPast.resetTimeRemaining(relativeTo: baseDate), "Resetting soon")
    }

    func testFormattedResetDate() {
        // 2026-09-08 10:00 UTC
        let date = Date(timeIntervalSince1970: 1788861600)
        let window = AIUsageWindow(usedPercent: 50, windowDurationMins: 10080, resetsAt: date)

        let formatted = window.formattedResetDate(
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "UTC")!
        )
        XCTAssertNotNil(formatted)
        XCTAssertTrue(formatted!.hasPrefix("Resets "))
    }
}
