import Foundation

/// Universal state of an AI agent's active execution cycle.
enum AIActivityState: String, Equatable, Sendable {
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
struct AIActivitySnapshot: Equatable, Sendable {
    let state: AIActivityState
    let sessionID: String?
    let model: String?
    let projectName: String?
    let updatedAt: Date

    init(
        state: AIActivityState = .idle,
        sessionID: String? = nil,
        model: String? = nil,
        projectName: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.state = state
        self.sessionID = sessionID
        self.model = model
        self.projectName = projectName
        self.updatedAt = updatedAt
    }

    /// Checks if a working session has gone stale without events for more than `timeoutSeconds`.
    func isStale(timeoutSeconds: TimeInterval = 45.0, now: Date = Date()) -> Bool {
        guard state == .working || state == .waitingForApproval else { return false }
        return now.timeIntervalSince(updatedAt) > timeoutSeconds
    }
}
