import Foundation

/// Universal state of an AI agent's active execution cycle.
enum AIActivityState: String, Codable, Equatable, Sendable {
    case idle = "idle"
    case working = "working"
    case waitingForApproval = "waiting_approval"
    case completed = "completed"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .waitingForApproval: return "Needs Approval"
        case .completed: return "Done"
        case .failed: return "Failed"
        }
    }
}

/// Generic session telemetry and activity state snapshot.
struct AIActivitySnapshot: Identifiable, Equatable, Sendable {
    var id: String {
        "\(providerID.rawValue)_\(sessionID ?? "active")"
    }

    let providerID: AIProviderID
    let state: AIActivityState
    let sessionID: String?
    let model: String?
    let projectName: String?
    let agentCount: Int?
    let updatedAt: Date

    init(
        providerID: AIProviderID = .claude,
        state: AIActivityState = .idle,
        sessionID: String? = nil,
        model: String? = nil,
        projectName: String? = nil,
        agentCount: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.state = state
        self.sessionID = sessionID
        self.model = model
        self.projectName = projectName
        self.agentCount = agentCount
        self.updatedAt = updatedAt
    }

    /// Checks if a working session has gone stale without events for more than `timeoutSeconds`.
    func isStale(timeoutSeconds: TimeInterval = 45.0, now: Date = Date()) -> Bool {
        guard state == .working || state == .waitingForApproval else { return false }
        return now.timeIntervalSince(updatedAt) > timeoutSeconds
    }
}
