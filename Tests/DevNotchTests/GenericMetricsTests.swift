import XCTest
@testable import DevNotch

final class GenericMetricsTests: XCTestCase {
    func testBalanceCompactMetric() {
        let balance = AIBalance(currency: "CNY", total: Decimal(string: "35.72")!, isAvailable: true)
        let metric = AICompactMetric(
            label: "DeepSeek",
            value: balance.formattedTotal,
            secondaryValue: nil,
            severity: .normal
        )

        XCTAssertEqual(metric.label, "DeepSeek")
        XCTAssertEqual(metric.value, "¥35.72")
        XCTAssertNil(metric.secondaryValue)
        XCTAssertEqual(metric.severity, .normal)
    }

    func testCriticalBalanceCompactMetric() {
        let balance = AIBalance(currency: "USD", total: Decimal(string: "0.00")!, isAvailable: false)
        let metric = AICompactMetric(
            label: "DeepSeek",
            value: balance.formattedTotal,
            secondaryValue: nil,
            severity: .critical
        )

        XCTAssertEqual(metric.value, "$0.00")
        XCTAssertEqual(metric.severity, .critical)
        XCTAssertEqual(metric.severity.color, .red)
    }

    func testUsageWindowCompactMetric() {
        let window = AIUsageWindow(id: "5h", label: "5 Hour", durationMinutes: 300, usedPercent: 16)
        let remaining = Int(round(window.remainingPercent))
        let metric = AICompactMetric(
            label: "Codex",
            value: "\(remaining)%",
            secondaryValue: "5h",
            severity: .normal
        )

        XCTAssertEqual(metric.label, "Codex")
        XCTAssertEqual(metric.value, "84%")
        XCTAssertEqual(metric.secondaryValue, "5h")
        XCTAssertEqual(metric.severity, .normal)
    }

    func testLowQuotaWarningSeverity() {
        let window = AIUsageWindow(id: "5h", label: "5 Hour", durationMinutes: 300, usedPercent: 88)
        let remaining = Int(round(window.remainingPercent))
        XCTAssertEqual(remaining, 12)

        let severity: AICompactMetricSeverity = remaining < 20 ? .warning : .normal
        let metric = AICompactMetric(
            label: "Codex",
            value: "\(remaining)%",
            secondaryValue: "5h",
            severity: severity
        )

        XCTAssertEqual(metric.severity, .warning)
        XCTAssertEqual(metric.severity.color, .orange)
    }

    func testMixedMetricsSnapshot() {
        let window = AIUsageWindow(id: "rolling", label: "5 Hour", durationMinutes: 300, usedPercent: 25)
        let credits = AICredits(balance: "$15.00", unlimited: false)
        let balance = AIBalance(currency: "CNY", total: Decimal(string: "100.00")!)

        let metrics: [AIProviderMetric] = [
            .usageWindow(window),
            .credits(credits),
            .balance(balance)
        ]

        XCTAssertEqual(metrics.count, 3)
        XCTAssertEqual(metrics[0].id, "window_rolling")
        XCTAssertEqual(metrics[1].id, "credits_$15.00")
        XCTAssertEqual(metrics[2].id, "balance_CNY")
    }
}
