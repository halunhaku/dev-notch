import SwiftUI

/// Elegant progress bar for an AI quota window (e.g. 5 Hour or Weekly quota).
struct AIUsageBar: View {
    let window: AIUsageWindow
    @Environment(\.locale) private var locale


    private var fillGradient: LinearGradient {
        let remaining = window.remainingPercent
        if remaining >= 40 {
            return LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if remaining >= 15 {
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.red, Color.pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
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
            // Header Row: Window Title & Remaining %
            HStack {
                Text(LocalizedStringKey(window.label))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text("\(Int(round(window.remainingPercent)))% remaining")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            // Progress Bar Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)

                    // Active Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fillGradient)
                        .frame(
                            width: max(0, min(geo.size.width, geo.size.width * CGFloat(window.remainingPercent / 100.0))),
                            height: 6
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: window.remainingPercent)
                }
            }
            .frame(height: 6)

            // Footer Row: Reset Time
            if !resetText.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.45))

                    Text(verbatim: resetText)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))

                    Spacer()
                }
            }
        }
    }
}
