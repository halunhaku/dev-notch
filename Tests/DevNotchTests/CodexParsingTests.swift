import XCTest
@testable import DevNotch

final class CodexParsingTests: XCTestCase {
    func testAccountReadParsing() throws {
        let json = """
        {
          "account": {
            "type": "chatgpt",
            "email": "user@example.com",
            "planType": "plus"
          },
          "requiresOpenaiAuth": true,
          "unknownFutureField": "ignoredSafely"
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(CodexAccountReadResult.self, from: data)

        XCTAssertNotNil(result.account)
        XCTAssertEqual(result.account?.email, "user@example.com")
        XCTAssertEqual(result.account?.planType, "plus")
        XCTAssertEqual(result.account?.type, "chatgpt")
        XCTAssertEqual(result.requiresOpenaiAuth, true)
    }

    func testRateLimitsReadParsing() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": {
              "usedPercent": 28.5,
              "windowDurationMins": 300,
              "resetsAt": 1788865101
            },
            "secondary": {
              "usedPercent": 16.0,
              "windowDurationMins": 10080,
              "resetsAt": 1789451901
            },
            "credits": {
              "hasCredits": false,
              "unlimited": false,
              "balance": "0"
            },
            "planType": "plus"
          }
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(CodexRateLimitsReadResult.self, from: data)

        let snapshot = try XCTUnwrap(result.rateLimits)
        XCTAssertEqual(snapshot.limitId, "codex")
        XCTAssertEqual(snapshot.planType, "plus")

        let primary = try XCTUnwrap(snapshot.primary)
        XCTAssertEqual(primary.usedPercent, 28.5)
        XCTAssertEqual(primary.windowDurationMins, 300)
        XCTAssertEqual(primary.resetsAt, 1788865101)

        let secondary = try XCTUnwrap(snapshot.secondary)
        XCTAssertEqual(secondary.usedPercent, 16.0)
        XCTAssertEqual(secondary.windowDurationMins, 10080)
        XCTAssertEqual(secondary.resetsAt, 1789451901)
    }

    func testRateLimitsUpdatedNotificationParsing() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {
              "usedPercent": 55.0,
              "windowDurationMins": 300,
              "resetsAt": 1788865101
            },
            "secondary": null
          }
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(CodexRateLimitsUpdatedParams.self, from: data)

        let snapshot = try XCTUnwrap(result.rateLimits)
        XCTAssertEqual(snapshot.limitId, "codex")
        XCTAssertEqual(snapshot.primary?.usedPercent, 55.0)
        XCTAssertNil(snapshot.secondary)
    }

    func testJSONRPCErrorPayloadParsing() throws {
        let json = """
        {
          "code": -32600,
          "message": "Invalid request: unknown variant `account/usage/read`"
        }
        """

        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(JSONRPCErrorPayload.self, from: data)

        XCTAssertEqual(error.code, -32600)
        XCTAssertTrue(error.message.contains("Invalid request"))
    }
}
