import Foundation

/// Dynamic representation of AI quota, strictly representing 0 to N usage windows.
struct AIUsage: Equatable, Sendable {
    /// 0...N rate-limit or quota windows (e.g. 5 Hour, Weekly, Monthly).
    let windows: [AIUsageWindow]
    /// Plan description.
    let planType: String?
    /// Timestamp of this usage snapshot.
    let updatedAt: Date

    init(
        windows: [AIUsageWindow],
        planType: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.windows = windows
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
