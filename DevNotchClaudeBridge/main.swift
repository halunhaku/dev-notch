import Foundation

// MARK: - Lightweight Metadata Structures (Zero prompt/response/code capture)

private struct BridgeContextWindow: Codable {
    let used_percentage: Double?
    let total_tokens: Int?
    let used_tokens: Int?
}

private struct BridgeInboundPayload: Codable {
    let session_id: String?
    let cwd: String?
    let model: String?
    let cost: Double?
    let context_window: BridgeContextWindow?
    let hook_event_name: String?
}

private struct BridgeOutboundSnapshot: Codable {
    let sessionID: String?
    let model: String?
    let projectName: String?
    let contextUsedPercent: Double?
    let sessionCostUSD: Decimal?
    let activityState: String
    let timestamp: Double
}

func main() {
    // 1. Determine event name from CLI argument or payload
    let argEvent = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil

    // 2. Read stdin
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    var payload: BridgeInboundPayload? = nil

    if !stdinData.isEmpty {
        payload = try? JSONDecoder().decode(BridgeInboundPayload.self, from: stdinData)
    }

    let eventName = argEvent ?? payload?.hook_event_name ?? "statusLine"

    // 3. Map event to AIActivityState
    var state = "idle"
    switch eventName {
    case "UserPromptSubmit", "PreToolUse", "PostToolUse":
        state = "working"
    case "PermissionRequest":
        state = "waiting_approval"
    case "Stop":
        state = "completed"
    case "SessionStart":
        state = "idle"
    default:
        // statusLine keeps existing state if known, or defaults to idle
        state = "idle"
    }

    // 4. Extract non-sensitive metadata only
    let sessionID = payload?.session_id
    let model = payload?.model
    let projectName = payload?.cwd.flatMap { ($0 as NSString).lastPathComponent }
    let contextPct = payload?.context_window?.used_percentage.map { $0 * 100.0 }
    let costUSD = payload?.cost.flatMap { Decimal($0) }

    let snapshot = BridgeOutboundSnapshot(
        sessionID: sessionID,
        model: model,
        projectName: projectName,
        contextUsedPercent: contextPct,
        sessionCostUSD: costUSD,
        activityState: state,
        timestamp: Date().timeIntervalSince1970
    )

    // 5. Write atomically to ~/Library/Application Support/DevNotch/Claude/session.json
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        exit(0)
    }

    let claudeDir = appSupport.appendingPathComponent("DevNotch/Claude", isDirectory: true)
    let targetURL = claudeDir.appendingPathComponent("session.json")
    let tempURL = claudeDir.appendingPathComponent("session_\(UUID().uuidString).tmp")

    do {
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: tempURL)
        _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: tempURL)
    } catch {
        // Fail silently and fast
    }
}

main()
