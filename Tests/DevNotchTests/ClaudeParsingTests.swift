import XCTest
@testable import DevNotch

final class ClaudeParsingTests: XCTestCase {
    func testClaudeExecutableDiscovery() {
        let path = ClaudeExecutableLocator.locate()
        XCTAssertNotNil(path)
        if let p = path {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: p))
        }
    }

    func testClaudeAuthSubscriptionFixture() throws {
        let json = """
        {
          "loggedIn": true,
          "authMethod": "claude.ai",
          "apiProvider": "firstParty",
          "email": "developer@example.com",
          "orgId": "org_uuid_12345",
          "orgName": "Developer Org",
          "subscriptionType": "pro"
        }
        """

        let status = try JSONDecoder().decode(ClaudeAuthStatus.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(status.loggedIn)
        XCTAssertEqual(status.authMethod, "claude.ai")
        XCTAssertEqual(status.email, "developer@example.com")
        XCTAssertEqual(status.subscriptionType, "pro")

        let mode: ClaudeAuthMode = .subscription(type: status.subscriptionType ?? "Pro", email: status.email)
        XCTAssertEqual(mode.displayTitle, "Claude Pro")
    }

    func testClaudeAuthApiKeyFixture() throws {
        let json = """
        {
          "loggedIn": true,
          "authMethod": "api_key",
          "apiProvider": "firstParty",
          "apiKeySource": "ANTHROPIC_API_KEY"
        }
        """

        let status = try JSONDecoder().decode(ClaudeAuthStatus.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(status.loggedIn)
        XCTAssertEqual(status.authMethod, "api_key")
        XCTAssertEqual(status.apiKeySource, "ANTHROPIC_API_KEY")

        let mode: ClaudeAuthMode = .apiKey(source: status.apiKeySource)
        XCTAssertEqual(mode.displayTitle, "API Key")
    }

    func testClaudeAuthUnknownMode() throws {
        let json = """
        {
          "loggedIn": true,
          "authMethod": "enterprise_sso",
          "apiProvider": "customGateway"
        }
        """

        let status = try JSONDecoder().decode(ClaudeAuthStatus.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(status.loggedIn)

        let mode: ClaudeAuthMode = .unknown(status.authMethod ?? "unknown")
        XCTAssertEqual(mode.displayTitle, "enterprise_sso")
    }

    func testStatusLinePayloadParsing() throws {
        let json = """
        {
          "session_id": "session-uuid-1234",
          "cwd": "/Users/developer/projects/DevNotch",
          "model": "claude-sonnet-4",
          "cost": 0.42,
          "context_window": {
            "used_percentage": 0.43,
            "total_tokens": 200000,
            "used_tokens": 86000
          },
          "unknown_future_field": "future_proof"
        }
        """

        let payload = try JSONDecoder().decode(ClaudeStatusLinePayload.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(payload.session_id, "session-uuid-1234")
        XCTAssertEqual(payload.model, "claude-sonnet-4")
        XCTAssertEqual(payload.cost, 0.42)

        let context = try XCTUnwrap(payload.context_window)
        XCTAssertEqual(context.used_percentage, 0.43)
        XCTAssertEqual(context.total_tokens, 200000)
        XCTAssertEqual(context.used_tokens, 86000)

        let contextMetric = AIContextMetric(usedPercent: context.used_percentage! * 100.0)
        XCTAssertEqual(contextMetric.formattedPercentage, "43% used")
        XCTAssertEqual(contextMetric.formattedRemaining, "57% remaining")

        let costDecimal = Decimal(payload.cost!)
        let costMetric = AISessionCostMetric(costUSD: costDecimal)
        XCTAssertEqual(costMetric.formattedCost, "$0.42")
    }
}
