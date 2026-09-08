import Foundation

/// Safe, non-sensitive session telemetry extracted from hook/statusLine payloads.
struct SanitizedActivityRecord: Codable, Equatable, Sendable {
    let providerID: String
    let sessionID: String?
    let model: String?
    let projectName: String?
    let contextUsedPercent: Double?
    let sessionCostUSD: Decimal?
    let agentCount: Int?
    let activityState: String
    let timestamp: Double

    init(
        providerID: String,
        sessionID: String? = nil,
        model: String? = nil,
        projectName: String? = nil,
        contextUsedPercent: Double? = nil,
        sessionCostUSD: Decimal? = nil,
        agentCount: Int? = nil,
        activityState: String = "idle",
        timestamp: Double = Date().timeIntervalSince1970
    ) {
        self.providerID = providerID
        self.sessionID = sessionID
        self.model = model
        self.projectName = projectName
        self.contextUsedPercent = contextUsedPercent
        self.sessionCostUSD = sessionCostUSD
        self.agentCount = agentCount
        self.activityState = activityState
        self.timestamp = timestamp
    }
}

/// Whitelist-only payload sanitizer.
/// Explicitly excludes all prompts, responses, tool arguments, and source code.
struct ActivityPayloadSanitizer: Sendable {
    static func sanitize(
        rawJSON: Data,
        provider: String,
        event: String
    ) -> SanitizedActivityRecord {
        var sessionID: String? = nil
        var model: String? = nil
        var projectName: String? = nil
        var contextUsedPercent: Double? = nil
        var sessionCostUSD: Decimal? = nil
        var agentCount: Int? = nil

        if let dict = (try? JSONSerialization.jsonObject(with: rawJSON)) as? [String: Any] {
            // 1. Session / Conversation ID (support both camelCase and snake_case)
            sessionID = (dict["conversationId"] as? String)
                ?? (dict["conversation_id"] as? String)
                ?? (dict["sessionId"] as? String)
                ?? (dict["session_id"] as? String)

            // 2. Model Name
            model = (dict["modelName"] as? String)
                ?? (dict["model_name"] as? String)
                ?? (dict["model"] as? String)

            // 3. Project / Workspace Name
            if let workspacePaths = dict["workspacePaths"] as? [String], let first = workspacePaths.first {
                projectName = (first as NSString).lastPathComponent
            } else if let cwd = dict["cwd"] as? String {
                projectName = (cwd as NSString).lastPathComponent
            }

            // 4. Context Window
            if let ctx = dict["context_window"] as? [String: Any],
               let usedPct = ctx["used_percentage"] as? Double {
                contextUsedPercent = usedPct * 100.0
            }

            // 5. Cost
            if let costNum = dict["cost"] as? Double {
                sessionCostUSD = Decimal(costNum)
            }

            // 6. Agent Count (if explicitly provided by provider)
            if let count = dict["agentCount"] as? Int ?? dict["agent_count"] as? Int {
                agentCount = count
            }
        }

        let state = mapEventToState(event: event, provider: provider)

        return SanitizedActivityRecord(
            providerID: provider,
            sessionID: sessionID,
            model: model,
            projectName: projectName,
            contextUsedPercent: contextUsedPercent,
            sessionCostUSD: sessionCostUSD,
            agentCount: agentCount,
            activityState: state,
            timestamp: Date().timeIntervalSince1970
        )
    }

    /// Maps provider-specific event strings to standardized AIActivityState.
    static func mapEventToState(event: String, provider: String) -> String {
        switch event {
        // Antigravity events
        case "PreInvocation", "PreToolUse", "PostToolUse", "PostInvocation":
            return "working"
        case "Stop":
            return "completed"

        // Claude events
        case "UserPromptSubmit":
            return "working"
        case "PermissionRequest":
            return "waiting_approval"
        case "SessionStart":
            return "idle"

        default:
            return "idle"
        }
    }
}
