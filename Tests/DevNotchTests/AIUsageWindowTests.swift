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

        // Unknown / irregular minutes (e.g. 45 mins, 75 mins)
        let w45m = AIUsageWindow(usedPercent: 10, windowDurationMins: 45, resetsAt: nil)
        XCTAssertEqual(w45m.label, "45m")

        let w75m = AIUsageWindow(usedPercent: 10, windowDurationMins: 75, resetsAt: nil)
        XCTAssertEqual(w75m.label, "75m")
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

    func testResetTimeRemainingWithNilAndPastDate() {
        // Nil resetsAt
        let wNil = AIUsageWindow(usedPercent: 20, windowDurationMins: 300, resetsAt: nil)
        XCTAssertNil(wNil.resetTimeRemaining())
        XCTAssertNil(wNil.formattedResetDate())

        let baseDate = Date(timeIntervalSince1970: 1700000000)

        // 2 hours 14 minutes in future (8040 seconds)
        let futureDate = baseDate.addingTimeInterval(8040)
        let window = AIUsageWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: futureDate)
        XCTAssertEqual(window.resetTimeRemaining(relativeTo: baseDate), "Reset in 2h 14m")

        // 45 minutes in future (2700 seconds)
        let future45m = baseDate.addingTimeInterval(2700)
        let window45m = AIUsageWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: future45m)
        XCTAssertEqual(window45m.resetTimeRemaining(relativeTo: baseDate), "Reset in 45m")

        // Past date
        let pastDate = baseDate.addingTimeInterval(-100)
        let windowPast = AIUsageWindow(usedPercent: 50, windowDurationMins: 300, resetsAt: pastDate)
        XCTAssertEqual(windowPast.resetTimeRemaining(relativeTo: baseDate), "Resetting soon")
    }

    func testAIUsageWithOneTwoAndThreeWindows() {
        let w1 = AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 20)
        let w2 = AIUsageWindow(id: "weekly", label: "Weekly", durationMinutes: 10080, usedPercent: 40)
        let w3 = AIUsageWindow(id: "monthly", label: "Monthly", durationMinutes: 43200, usedPercent: 60)

        // 1 Window
        let usage1 = AIUsage(windows: [w1])
        XCTAssertEqual(usage1.windows.count, 1)
        XCTAssertEqual(usage1.primaryRemainingInt, 80)

        // 2 Windows
        let usage2 = AIUsage(windows: [w1, w2])
        XCTAssertEqual(usage2.windows.count, 2)
        XCTAssertEqual(usage2.primaryRemainingInt, 80)

        // 3 Windows
        let usage3 = AIUsage(windows: [w1, w2, w3])
        XCTAssertEqual(usage3.windows.count, 3)
        XCTAssertEqual(usage3.primaryRemainingInt, 80)
    }
}
