import Foundation

/// Official DeepSeek balance response schema: `GET /user/balance`.
struct DeepSeekBalanceResponse: Decodable, Sendable {
    let isAvailable: Bool
    let balanceInfos: [DeepSeekBalanceInfo]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

/// Official DeepSeek currency balance details.
struct DeepSeekBalanceInfo: Decodable, Sendable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }

    /// Exact decimal conversion to guarantee financial precision.
    var totalDecimal: Decimal {
        Decimal(string: totalBalance) ?? .zero
    }

    var grantedDecimal: Decimal {
        Decimal(string: grantedBalance) ?? .zero
    }

    var toppedUpDecimal: Decimal {
        Decimal(string: toppedUpBalance) ?? .zero
    }
}
