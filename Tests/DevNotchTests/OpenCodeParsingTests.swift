import XCTest
@testable import DevNotch

final class OpenCodeParsingTests: XCTestCase {
    func testOpenCodeGoPayloadParsingWithThreeWindows() throws {
        let json = """
        {
          "rollingUsage": {
            "usagePercent": 33.0,
            "resetInSec": 7200
          },
          "weeklyUsage": {
            "usagePercent": 48.0,
            "resetInSec": 360000
          },
          "monthlyUsage": {
            "usagePercent": 12.0,
            "resetInSec": 1800000
          },
          "balance": 25.50,
          "renewsAt": 1789451901
        }
        """

        let data = json.data(using: .utf8)!
        let payload = try JSONDecoder().decode(OpenCodeGoUsagePayload.self, from: data)

        let baseDate = Date(timeIntervalSince1970: 1788865101)
        let (usage, credits) = OpenCodeGoProvider.mapPayloadToUsage(payload, now: baseDate)

        XCTAssertEqual(usage.windows.count, 3)

        // Rolling 5h
        let rolling = try XCTUnwrap(usage.windows.first(where: { $0.id == "rolling" }))
        XCTAssertEqual(rolling.label, "5 Hour")
        XCTAssertEqual(rolling.usedPercent, 33.0)
        XCTAssertEqual(rolling.remainingPercent, 67.0)
        XCTAssertEqual(rolling.resetsAt, baseDate.addingTimeInterval(7200))

        // Weekly
        let weekly = try XCTUnwrap(usage.windows.first(where: { $0.id == "weekly" }))
        XCTAssertEqual(weekly.label, "Weekly")
        XCTAssertEqual(weekly.usedPercent, 48.0)
        XCTAssertEqual(weekly.remainingPercent, 52.0)

        // Monthly
        let monthly = try XCTUnwrap(usage.windows.first(where: { $0.id == "monthly" }))
        XCTAssertEqual(monthly.label, "Monthly")
        XCTAssertEqual(monthly.usedPercent, 12.0)
        XCTAssertEqual(monthly.remainingPercent, 88.0)

        // Credit balance
        XCTAssertEqual(credits?.balance, "$25.50")
    }

    func testOpenCodeGoPayloadWithUnknownFields() throws {
        let json = """
        {
          "rollingUsage": {
            "usagePercent": 50.0,
            "resetInSec": 3600,
            "extraServerMetric": "ignored"
          },
          "weeklyUsage": null,
          "monthlyUsage": null,
          "unknownFutureObject": { "test": 123 }
        }
        """

        let data = json.data(using: .utf8)!
        let payload = try JSONDecoder().decode(OpenCodeGoUsagePayload.self, from: data)
        let (usage, _) = OpenCodeGoProvider.mapPayloadToUsage(payload)

        XCTAssertEqual(usage.windows.count, 1)
        XCTAssertEqual(usage.windows[0].remainingPercent, 50.0)
    }

    func testOpenCodeGoMalformedResponseHandling() {
        let invalidJson = "{ malformed: json [ }".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(OpenCodeGoUsagePayload.self, from: invalidJson))
    }

    func testRealOpenCodeGoOfficialApiPayloadParsing() throws {
        let json = """
        {
          "usage": {
            "rolling": {
              "status": "ok",
              "percent": 4,
              "resetsAt": "2026-09-08T18:14:01.178Z"
            },
            "weekly": {
              "status": "ok",
              "percent": 4,
              "resetsAt": "2026-09-14T00:00:00.178Z"
            },
            "monthly": {
              "status": "ok",
              "percent": 26,
              "resetsAt": "2026-10-01T12:25:20.178Z"
            }
          }
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(OpenCodeGoUsagePayload.self, from: json)
        let (usage, _) = OpenCodeGoProvider.mapPayloadToUsage(payload)

        XCTAssertEqual(usage.windows.count, 3)

        let rolling = try XCTUnwrap(usage.windows.first(where: { $0.id == "rolling" }))
        XCTAssertEqual(rolling.usedPercent, 4.0)
        XCTAssertEqual(rolling.remainingPercent, 96.0)

        let weekly = try XCTUnwrap(usage.windows.first(where: { $0.id == "weekly" }))
        XCTAssertEqual(weekly.usedPercent, 4.0)
        XCTAssertEqual(weekly.remainingPercent, 96.0)

        let monthly = try XCTUnwrap(usage.windows.first(where: { $0.id == "monthly" }))
        XCTAssertEqual(monthly.usedPercent, 26.0)
        XCTAssertEqual(monthly.remainingPercent, 74.0)
    }
}
