import Foundation

/// Provider credit balance representation (if available).
struct AICredits: Equatable, Sendable {
    let balance: String?
    let unlimited: Bool
}

/// Dynamic representation of AI quota, supporting 0 to N usage windows.
struct AIUsage: Equatable, Sendable {
    /// 0...N rate-limit or quota windows (e.g. 5 Hour, Weekly, Monthly).
    let windows: [AIUsageWindow]
    /// Credit balance (e.g. pay-as-you-go balance or unlimited indicator).
    let credits: AICredits?
    /// Plan description.
    let planType: String?
    /// Timestamp of this usage snapshot.
    let updatedAt: Date

    init(
        windows: [AIUsageWindow],
        credits: AICredits? = nil,
        planType: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.windows = windows
        self.credits = credits
        self.planType = planType
        self.updatedAt = updatedAt
    }

    /// Primary display window (defaults to first available window).
    var primaryWindow: AIUsageWindow? {
        windows.first
    }

    /// Primary remaining percentage for compact/hovered notch indicators.
    var primaryRemainingPercent: Double? {
        primaryWindow?.remainingPercent
    }

    /// Primary remaining percentage as an integer (0...100).
    var primaryRemainingInt: Int? {
        primaryRemainingPercent.map { Int(round($0)) }
    }
}
