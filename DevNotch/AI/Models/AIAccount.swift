import Foundation

/// Provider-agnostic account information.
struct AIAccount: Equatable, Sendable {
    let email: String?
    let planType: String?
    let accountType: String?

    init(email: String? = nil, planType: String? = nil, accountType: String? = nil) {
        self.email = email
        self.planType = planType
        self.accountType = accountType
    }

    var displayPlanName: String {
        guard let plan = planType, !plan.isEmpty else { return "Standard" }
        // Format common plan types (e.g. "plus" -> "Plus", "pro" -> "Pro", "team" -> "Team")
        return plan.prefix(1).uppercased() + plan.dropFirst()
    }
}
