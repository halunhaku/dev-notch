import SwiftUI

/// Elegant progress bar for an AI quota window (e.g. 5 Hour or Weekly quota).
struct AIUsageBar: View {
    let window: AIUsageWindow
    @Environment(\.locale) private var locale

    private var tint: Color {
        DNTheme.quotaTint(remainingPercent: window.remainingPercent, brand: DNTheme.Color.accent)
    }

    private var resetText: String {
        if window.windowDurationMins >= 1440 {
            return window.formattedResetDate(locale: locale) ?? (window.resetTimeRemaining(locale: locale) ?? "")
        } else {
            return window.resetTimeRemaining(locale: locale) ?? ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(LocalizedStringKey(window.label))
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textSecondary)
                Spacer()
                Text("\(Int(round(window.remainingPercent)))% remaining")
                    .font(DNTheme.Typeface.caption)
                    .monospacedDigit()
                    .foregroundStyle(DNTheme.Color.textPrimary)
            }

            DNProgressBar(progress: window.remainingPercent / 100.0, tint: tint)

            if !resetText.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    Text(verbatim: resetText)
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
