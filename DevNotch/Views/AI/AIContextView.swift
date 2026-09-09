import SwiftUI

/// Progress bar and indicator for active conversation Context Window.
struct AIContextView: View {
    let context: AIContextMetric

    private var tint: Color {
        if context.usedPercent > 90 { return DNTheme.Color.critical }
        if context.usedPercent > 70 { return DNTheme.Color.warning }
        return DNTheme.Color.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Context Window")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textSecondary)
                Spacer()
                Text(context.formattedPercentage)
                    .font(DNTheme.Typeface.caption)
                    .monospacedDigit()
                    .foregroundStyle(DNTheme.Color.textPrimary)
            }

            DNProgressBar(progress: context.usedPercent / 100.0, tint: tint)

            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 8))
                    .foregroundStyle(DNTheme.Color.textTertiary)
                Text("\(context.formattedRemaining) in current session")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
                Spacer()
            }
        }
        .padding(9)
        .background(DNTheme.Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: DNTheme.Radius.chip, style: .continuous))
    }
}
