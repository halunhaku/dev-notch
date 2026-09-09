import XCTest
@testable import DevNotch

final class GrokAuthTests: XCTestCase {
    func testAuthJSONWithRefreshableSessionIsAuthenticated() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grok_auth_\(UUID().uuidString).json")
        let json = """
        {
          "https://auth.x.ai::test-id": {
            "auth_mode": "oidc",
            "email": "dev@example.com",
            "user_id": "user-1",
            "expires_at": "2099-01-01T00:00:00.000Z",
            "refresh_token": "dummy-refresh",
            "key": "dummy-key"
          }
        }
        """
        try json.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = GrokAuthInspector.inspect(customAuthPath: url.path)
        XCTAssertTrue(info.isAuthenticated)
        XCTAssertEqual(info.email, "dev@example.com")
        XCTAssertEqual(info.authMode, "oidc")
        XCTAssertEqual(info.credentialSource, .grokCLI)
    }

    func testExpiredSessionWithoutRefreshIsUnauthenticated() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grok_auth_\(UUID().uuidString).json")
        let json = """
        {
          "https://auth.x.ai::test-id": {
            "auth_mode": "oidc",
            "email": "dev@example.com",
            "user_id": "user-1",
            "expires_at": "2020-01-01T00:00:00Z"
          }
        }
        """
        try json.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = GrokAuthInspector.inspect(customAuthPath: url.path)
        if ProcessInfo.processInfo.environment["XAI_API_KEY"] == nil {
            XCTAssertFalse(info.isAuthenticated)
            XCTAssertNil(info.email)
        }
    }

    func testMissingAuthFileIsUnauthenticated() {
        let info = GrokAuthInspector.inspect(customAuthPath: "/tmp/missing_grok_auth_\(UUID().uuidString).json")
        if ProcessInfo.processInfo.environment["XAI_API_KEY"] == nil {
            XCTAssertFalse(info.isAuthenticated)
        }
    }

    func testLoadSessionExposesBearerWithoutLoggingRequirement() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grok_auth_\(UUID().uuidString).json")
        let json = """
        {
          "https://auth.x.ai::test-id": {
            "auth_mode": "oidc",
            "email": "dev@example.com",
            "user_id": "user-1",
            "expires_at": "2099-01-01T00:00:00Z",
            "key": "dummy-key"
          }
        }
        """
        try json.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = GrokAuthInspector.loadSession(customAuthPath: url.path)
        XCTAssertTrue(session.info.isAuthenticated)
        XCTAssertEqual(session.accessToken, "dummy-key")
    }

    func testCreditsSnapshotParsesWeeklyUsagePercent() throws {
        let json = """
        {
          "config": {
            "currentPeriod": {
              "type": "USAGE_PERIOD_TYPE_WEEKLY",
              "start": "2026-09-09T00:35:34.798174+00:00",
              "end": "2026-09-16T00:35:34.798174+00:00"
            },
            "creditUsagePercent": 2.0,
            "onDemandCap": { "val": 0 },
            "onDemandUsed": { "val": 0 },
            "billingPeriodEnd": "2026-09-16T00:35:34.798174+00:00"
          }
        }
        """
        let snapshot = try GrokCreditsClient.parseSnapshot(Data(json.utf8))
        XCTAssertEqual(snapshot.usedPercent, 2.0)
        XCTAssertEqual(snapshot.durationMinutes, 10_080)
        XCTAssertEqual(snapshot.label, "Weekly")
        XCTAssertNotNil(snapshot.resetsAt)
    }

    func testISO8601OffsetWithFractionalSeconds() {
        let date = GrokISO8601.parse("2026-09-16T00:35:34.798174+00:00")
        XCTAssertNotNil(date)
    }
}
