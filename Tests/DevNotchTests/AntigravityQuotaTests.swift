import XCTest
@testable import DevNotch

final class AntigravityQuotaTests: XCTestCase {
    func testParseAntigravityQuotaSummary() {
        let json = """
        {
          "response": {
            "groups": [
              {
                "displayName": "Gemini Models",
                "buckets": [
                  {
                    "bucketId": "gemini-5h",
                    "displayName": "Five Hour Limit Remaining",
                    "remainingFraction": 0.70,
                    "resetTime": "2026-09-08T19:02:44Z"
                  },
                  {
                    "bucketId": "gemini-weekly",
                    "displayName": "Weekly Limit Remaining",
                    "remainingFraction": 0.186,
                    "resetTime": "2026-09-12T07:55:40Z"
                  }
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let usage = AntigravityQuotaProbe.parseQuotaSummary(data: json)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.windows.count, 2)

        let fiveHour = usage?.windows.first { $0.label.contains("5-Hour") }
        XCTAssertNotNil(fiveHour)
        XCTAssertEqual(fiveHour?.usedPercent ?? 0, 30.0, accuracy: 0.1)
        XCTAssertEqual(fiveHour?.remainingPercent ?? 0, 70.0, accuracy: 0.1)

        let weekly = usage?.windows.first { $0.label.contains("Weekly") }
        XCTAssertNotNil(weekly)
        XCTAssertEqual(weekly?.usedPercent ?? 0, 81.4, accuracy: 0.1)
        XCTAssertEqual(weekly?.remainingPercent ?? 0, 18.6, accuracy: 0.1)
    }
}
