import Foundation

/// Provider credit balance representation (if available).
struct AICredits: Equatable, Sendable {
    let balance: String?
    let unlimited: Bool

    init(balance: String? = nil, unlimited: Bool = false) {
        self.balance = balance
        self.unlimited = unlimited
    }
}
