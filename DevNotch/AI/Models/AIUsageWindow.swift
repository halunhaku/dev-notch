import Foundation

/// Represents a single rate-limit window (e.g. 5 Hour or Weekly quota).
struct AIUsageWindow: Equatable, Sendable {
    /// Percentage of quota consumed (0.0 to 100.0).
    let usedPercent: Double
    /// Duration of the quota window in minutes (e.g. 300 for 5h, 10080 for Weekly).
    let windowDurationMins: Int
    /// Date when this window resets.
    let resetsAt: Date?

    /// Percentage of quota remaining (0.0 to 100.0).
    var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - usedPercent))
    }

    /// User-friendly label for the quota window duration.
    var label: String {
        switch windowDurationMins {
        case 60:
            return "1 Hour"
        case 300:
            return "5 Hour"
        case 1440:
            return "Daily"
        case 10080:
            return "Weekly"
        default:
            if windowDurationMins >= 1440 && windowDurationMins % 1440 == 0 {
                let days = windowDurationMins / 1440
                return "\(days) Day"
            } else if windowDurationMins >= 60 && windowDurationMins % 60 == 0 {
                let hours = windowDurationMins / 60
                return "\(hours) Hour"
            } else {
                return "\(windowDurationMins)m"
            }
        }
    }

    /// Human-readable relative time until quota reset.
    func resetTimeRemaining(relativeTo now: Date = Date()) -> String? {
        guard let resetsAt = resetsAt else { return nil }
        let diff = resetsAt.timeIntervalSince(now)
        if diff <= 0 {
            return "Resetting soon"
        }
        let totalMinutes = Int(ceil(diff / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "Reset in \(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "Reset in \(hours)h \(minutes)m"
        } else {
            return "Reset in \(minutes)m"
        }
    }

    /// Formatted absolute reset date using system locale and timezone.
    func formattedResetDate(locale: Locale = .current, timeZone: TimeZone = .current) -> String? {
        guard let resetsAt = resetsAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE HH:mm"
        return "Resets \(formatter.string(from: resetsAt))"
    }
}
