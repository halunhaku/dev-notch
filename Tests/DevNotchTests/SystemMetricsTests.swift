import XCTest
@testable import DevNotch

@MainActor
final class SystemMetricsTests: XCTestCase {
    func testCPUUsageUsesTickDeltasAndHandlesCounterWrap() {
        let previous = CPUTickSnapshot(user: .max - 4, system: 100, nice: 50, idle: 200)
        let current = CPUTickSnapshot(user: 5, system: 120, nice: 60, idle: 260)

        let usage = SystemMetricsSampler.cpuUsage(from: previous, to: current)

        XCTAssertEqual(usage, 40.0 / 100.0, accuracy: 0.0001)
    }

    func testNetworkRateUsesElapsedTimeAndIgnoresCounterReset() {
        let start = Date(timeIntervalSince1970: 1_000)
        let previous = NetworkCounterSnapshot(
            interfaceName: "en0",
            receivedBytes: 1_000,
            sentBytes: 800,
            timestamp: start
        )
        let current = NetworkCounterSnapshot(
            interfaceName: "en0",
            receivedBytes: 5_000,
            sentBytes: 2_800,
            timestamp: start.addingTimeInterval(2)
        )

        let rates = SystemMetricsSampler.networkRates(from: previous, to: current, duration: 2)
        XCTAssertEqual(rates.download, 2_000, accuracy: 0.001)
        XCTAssertEqual(rates.upload, 1_000, accuracy: 0.001)

        let reset = NetworkCounterSnapshot(
            interfaceName: "en0",
            receivedBytes: 10,
            sentBytes: 20,
            timestamp: start.addingTimeInterval(3)
        )
        let resetRates = SystemMetricsSampler.networkRates(from: current, to: reset, duration: 1)
        XCTAssertEqual(resetRates.download, 0)
        XCTAssertEqual(resetRates.upload, 0)
    }

    func testMetricHistoryKeepsNewestSamplesInOrder() {
        var history = MetricHistory(capacity: 3)
        history.append(1)
        history.append(2)
        history.append(3)
        history.append(4)

        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[0], 2)
        XCTAssertEqual(history[1], 3)
        XCTAssertEqual(history[2], 4)
        XCTAssertEqual(history.maximum, 4)
    }
}
