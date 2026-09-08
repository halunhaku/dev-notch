import Foundation

/// Represents the monetary cost incurred in the current interactive session.
struct AISessionCostMetric: Identifiable, Equatable, Sendable {
    let id: String
    let costUSD: Decimal
    let currency: String

    init(id: String = "session_cost", costUSD: Decimal, currency: String = "USD") {
        self.id = id
        self.costUSD = costUSD
        self.currency = currency
    }

    var formattedCost: String {
        AIBalance.format(amount: costUSD, currency: currency)
    }
}
