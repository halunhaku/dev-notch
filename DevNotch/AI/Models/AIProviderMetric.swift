import Foundation

/// Unified generic metric type representing diverse AI billing, quota, balance, and session context models.
enum AIProviderMetric: Identifiable, Equatable, Sendable {
    case usageWindow(AIUsageWindow)
    case balance(AIBalance)
    case credits(AICredits)
    case context(AIContextMetric)
    case sessionCost(AISessionCostMetric)

    var id: String {
        switch self {
        case .usageWindow(let window):
            return "window_\(window.id)"
        case .balance(let balance):
            return "balance_\(balance.id)"
        case .credits(let credits):
            return "credits_\(credits.balance ?? "default")"
        case .context(let context):
            return "context_\(context.id)"
        case .sessionCost(let cost):
            return "cost_\(cost.id)"
        }
    }
}
