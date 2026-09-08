import Foundation

/// Represents a monetary account balance with financial decimal precision.
struct AIBalance: Identifiable, Equatable, Sendable {
    let id: String
    let currency: String
    let total: Decimal
    let granted: Decimal
    let toppedUp: Decimal
    let isAvailable: Bool

    init(
        id: String? = nil,
        currency: String,
        total: Decimal,
        granted: Decimal = .zero,
        toppedUp: Decimal = .zero,
        isAvailable: Bool = true
    ) {
        self.currency = currency
        self.id = id ?? currency
        self.total = total
        self.granted = granted
        self.toppedUp = toppedUp
        self.isAvailable = isAvailable
    }

    /// Formats the total balance into a localized currency string (e.g. "¥0.73" or "$12.45").
    var formattedTotal: String {
        Self.format(amount: total, currency: currency)
    }

    /// Formats the topped-up balance into a localized currency string.
    var formattedToppedUp: String {
        Self.format(amount: toppedUp, currency: currency)
    }

    /// Formats the granted/promotional balance into a localized currency string.
    var formattedGranted: String {
        Self.format(amount: granted, currency: currency)
    }

    /// Currency symbol (e.g. "¥", "$", "€").
    var currencySymbol: String {
        switch currency.uppercased() {
        case "CNY", "RMB": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return currency
        }
    }

    /// Formats a Decimal with exact currency symbol and 2 decimal places.
    static func format(amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        switch currency.uppercased() {
        case "CNY", "RMB":
            formatter.currencySymbol = "¥"
        case "USD":
            formatter.currencySymbol = "$"
        case "EUR":
            formatter.currencySymbol = "€"
        case "GBP":
            formatter.currencySymbol = "£"
        default:
            break
        }

        let nsNum = NSDecimalNumber(decimal: amount)
        return formatter.string(from: nsNum) ?? "\(currency) \(amount)"
    }
}
