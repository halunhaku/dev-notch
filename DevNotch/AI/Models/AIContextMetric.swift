import Foundation

/// Represents the active conversation context window utilization.
struct AIContextMetric: Identifiable, Equatable, Sendable {
    let id: String
    /// Percentage of the model's context window consumed (0.0 to 100.0).
    let usedPercent: Double
    let totalTokens: Int?
    let usedTokens: Int?

    init(
        id: String = "context",
        usedPercent: Double,
        totalTokens: Int? = nil,
        usedTokens: Int? = nil
    ) {
        self.id = id
        self.usedPercent = max(0.0, min(100.0, usedPercent))
        self.totalTokens = totalTokens
        self.usedTokens = usedTokens
    }

    var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - usedPercent))
    }

    var formattedPercentage: String {
        "\(Int(round(usedPercent)))% used"
    }

    var formattedRemaining: String {
        "\(Int(round(remainingPercent)))% remaining"
    }
}
