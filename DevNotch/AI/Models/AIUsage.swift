import Foundation

/// Unified representation of AI usage and rate limits.
struct AIUsage: Equatable, Sendable {
    /// Primary fast rate limit window (e.g. 5 Hour limit).
    let primary: AIUsageWindow?
    /// Secondary slow rate limit window (e.g. Weekly limit).
    let secondary: AIUsageWindow?
    /// Account plan type associated with these rate limits.
    let planType: String?
    /// Timestamp when this snapshot was fetched or updated.
    let updatedAt: Date

    init(
        primary: AIUsageWindow?,
        secondary: AIUsageWindow? = nil,
        planType: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.updatedAt = updatedAt
    }

    /// Primary remaining percentage for quick display in compact and hovered notch states.
    var primaryRemainingPercent: Double? {
        primary?.remainingPercent ?? secondary?.remainingPercent
    }

    /// Rounded integer percentage for concise UI badges (0...100).
    var primaryRemainingInt: Int? {
        primaryRemainingPercent.map { Int(round($0)) }
    }
}
