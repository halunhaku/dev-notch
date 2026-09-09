import Foundation

/// Represents a single rate-limit or quota window (e.g. 5 Hour, Weekly, Monthly, or custom duration).
struct AIUsageWindow: Identifiable, Equatable, Sendable {
    /// Unique identifier for this window within the provider (e.g. "5h", "weekly", "monthly", "rolling").
    let id: String
    /// Human-readable label for the window (e.g. "5 Hour", "Weekly", "Monthly").
    let label: String
    /// Duration of the quota window in minutes (e.g. 300 for 5h, 10080 for Weekly, 43200 for Monthly).
    let durationMinutes: Int
    /// Percentage of quota consumed (0.0 to 100.0).
    let usedPercent: Double
    /// Date when this quota window resets.
    let resetsAt: Date?

    init(
        id: String? = nil,
        label: String? = nil,
        durationMinutes: Int,
        usedPercent: Double,
        resetsAt: Date? = nil
    ) {
        self.durationMinutes = durationMinutes
        self.id = id ?? Self.defaultId(for: durationMinutes)
        self.label = label ?? Self.defaultLabel(for: durationMinutes)
        self.usedPercent = max(0.0, min(100.0, usedPercent))
        self.resetsAt = resetsAt
    }

    /// Convenience initializer mapping from older windowDurationMins property.
    init(
        usedPercent: Double,
        windowDurationMins: Int,
        resetsAt: Date? = nil
    ) {
        self.init(
            id: nil,
            label: nil,
            durationMinutes: windowDurationMins,
            usedPercent: usedPercent,
            resetsAt: resetsAt
        )
    }

    /// Backward compatibility accessor.
    var windowDurationMins: Int {
        durationMinutes
    }

    /// Percentage of quota remaining (0.0 to 100.0).
    var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - usedPercent))
    }

    /// Default ID based on duration.
    static func defaultId(for durationMinutes: Int) -> String {
        switch durationMinutes {
        case 60: return "1h"
        case 300: return "5h"
        case 1440: return "daily"
        case 10080: return "weekly"
        case 43200: return "monthly"
        default: return "\(durationMinutes)m"
        }
    }

    /// Default human-readable label based on duration.
    static func defaultLabel(for durationMinutes: Int) -> String {
        switch durationMinutes {
        case 60:
            return "1 Hour"
        case 300:
            return "5 Hour"
        case 1440:
            return "Daily"
        case 10080:
            return "Weekly"
        case 43200:
            return "Monthly"
        default:
            if durationMinutes >= 1440 && durationMinutes % 1440 == 0 {
                let days = durationMinutes / 1440
                return "\(days) Day"
            } else if durationMinutes >= 60 && durationMinutes % 60 == 0 {
                let hours = durationMinutes / 60
                return "\(hours) Hour"
            } else {
                return "\(durationMinutes)m"
            }
        }
    }

    /// Human-readable relative time until quota reset.
    func resetTimeRemaining(relativeTo now: Date = Date(), locale: Locale = Locale(identifier: "en")) -> String? {
        guard let resetsAt = resetsAt else { return nil }
        let diff = resetsAt.timeIntervalSince(now)
        if diff <= 0 {
            return L10n.key("Resetting soon", locale: locale)
        }
        let totalMinutes = Int(ceil(diff / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return L10n.format("Reset in %dd %dh", locale: locale, days, remainingHours)
        } else if hours > 0 {
            return L10n.format("Reset in %dh %dm", locale: locale, hours, minutes)
        } else {
            return L10n.format("Reset in %dm", locale: locale, minutes)
        }
    }

    /// Formatted absolute reset date using the given locale and timezone.
    func formattedResetDate(locale: Locale = Locale(identifier: "en"), timeZone: TimeZone = .current) -> String? {
        guard let resetsAt = resetsAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE HH:mm"
        return L10n.format("Resets %@", locale: locale, formatter.string(from: resetsAt))
    }
}
