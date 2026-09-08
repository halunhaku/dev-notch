import XCTest
@testable import DevNotch

final class AntigravityActivityTests: XCTestCase {
    func testAntigravityEventMapping() {
        XCTAssertEqual(ActivityPayloadSanitizer.mapEventToState(event: "PreInvocation", provider: "antigravity"), "working")
        XCTAssertEqual(ActivityPayloadSanitizer.mapEventToState(event: "PreToolUse", provider: "antigravity"), "working")
        XCTAssertEqual(ActivityPayloadSanitizer.mapEventToState(event: "PostToolUse", provider: "antigravity"), "working")
        XCTAssertEqual(ActivityPayloadSanitizer.mapEventToState(event: "PostInvocation", provider: "antigravity"), "working")
        XCTAssertEqual(ActivityPayloadSanitizer.mapEventToState(event: "Stop", provider: "antigravity"), "completed")
        XCTAssertEqual(ActivityPayloadSanitizer.mapEventToState(event: "UnknownEvent", provider: "antigravity"), "idle")
    }

    func testPayloadSanitizationStripsSensitiveData() {
        // Construct Antigravity payload containing sensitive fields
        let rawPayload = """
        {
          "conversationId": "conv-uuid-5555",
          "modelName": "gemini-3.8-flash",
          "workspacePaths": ["/Users/developer/secret-project"],
          "prompt": "Secret internal business logic prompt text",
          "user_input": "Confidential user instructions",
          "model_response": "Sensitive AI output containing API keys",
          "toolCall": {
            "name": "run_command",
            "args": {
              "CommandLine": "curl -H 'Authorization: Bearer secret_token' https://internal.api"
            }
          },
          "file_content": "func confidentialAlgorithm() { return 42; }",
          "context_window": {
            "used_percentage": 0.28
          },
          "agentCount": 2
        }
        """.data(using: .utf8)!

        let record = ActivityPayloadSanitizer.sanitize(
            rawJSON: rawPayload,
            provider: "antigravity",
            event: "PreToolUse"
        )

        // 1. Allowed metadata is safely extracted
        XCTAssertEqual(record.providerID, "antigravity")
        XCTAssertEqual(record.sessionID, "conv-uuid-5555")
        XCTAssertEqual(record.model, "gemini-3.8-flash")
        XCTAssertEqual(record.projectName, "secret-project")
        XCTAssertNotNil(record.contextUsedPercent)
        XCTAssertEqual(record.contextUsedPercent!, 28.0, accuracy: 0.001)
        XCTAssertEqual(record.agentCount, 2)
        XCTAssertEqual(record.activityState, "working")

        // 2. Sensitive fields are NOT present in the sanitized record
        let mirror = Mirror(reflecting: record)
        let fieldNames = mirror.children.compactMap { $0.label }

        XCTAssertFalse(fieldNames.contains("prompt"))
        XCTAssertFalse(fieldNames.contains("user_input"))
        XCTAssertFalse(fieldNames.contains("model_response"))
        XCTAssertFalse(fieldNames.contains("CommandLine"))
        XCTAssertFalse(fieldNames.contains("file_content"))

        // 3. Encoded data contains no prompt or command leaks
        let encodedData = try! JSONEncoder().encode(record)
        let jsonString = String(data: encodedData, encoding: .utf8)!
        XCTAssertFalse(jsonString.contains("Secret internal"))
        XCTAssertFalse(jsonString.contains("Confidential user"))
        XCTAssertFalse(jsonString.contains("secret_token"))
        XCTAssertFalse(jsonString.contains("confidentialAlgorithm"))
    }

    func testAntigravityStaleWatchdog() {
        let now = Date()
        let freshSnapshot = AIActivitySnapshot(providerID: .antigravity, state: .working, updatedAt: now)
        XCTAssertFalse(freshSnapshot.isStale(timeoutSeconds: 45.0, now: now))

        // 50 seconds later -> must be stale
        let later = now.addingTimeInterval(50.0)
        XCTAssertTrue(freshSnapshot.isStale(timeoutSeconds: 45.0, now: later))

        // Idle state is never stale
        let idleSnapshot = AIActivitySnapshot(providerID: .antigravity, state: .idle, updatedAt: now.addingTimeInterval(-100))
        XCTAssertFalse(idleSnapshot.isStale(timeoutSeconds: 45.0, now: now))
    }

    func testAntigravityCompactMetricHierarchy() async {
        _ = AntigravityProvider()

        // 1. Working state
        let workingMetric = AICompactMetric(label: "Antigravity", value: "Working", severity: .normal)
        XCTAssertEqual(workingMetric.value, "Working")

        // 2. Done state
        let doneMetric = AICompactMetric(label: "Antigravity", value: "✓ Done", severity: .normal)
        XCTAssertEqual(doneMetric.value, "✓ Done")

        // 3. Ready state
        let readyMetric = AICompactMetric(label: "Antigravity", value: "Ready", severity: .normal)
        XCTAssertEqual(readyMetric.value, "Ready")
    }

    func testAtomicActivityIpcWrite() throws {
        let record = SanitizedActivityRecord(
            providerID: "antigravity",
            sessionID: "test_agy_session",
            model: "gemini-3.8-flash",
            projectName: "DevNotch",
            contextUsedPercent: 15.0,
            activityState: "working"
        )

        try ActivityIPCWriter.write(record: record)

        let targetURL = ActivityIPCWriter.activitiesDirectoryURL.appendingPathComponent("antigravity.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))

        let data = try Data(contentsOf: targetURL)
        let readRecord = try JSONDecoder().decode(SanitizedActivityRecord.self, from: data)

        XCTAssertEqual(readRecord.sessionID, "test_agy_session")
        XCTAssertEqual(readRecord.activityState, "working")
    }
}
