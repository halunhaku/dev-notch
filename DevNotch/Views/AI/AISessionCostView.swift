import SwiftUI

/// Displays session cost incurred in the active conversation (API Key users).
struct AISessionCostView: View {
    let cost: AISessionCostMetric

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Session Cost")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textSecondary)
                Text("Current conversation spend")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
            }
            Spacer()
            DNMetricText(text: cost.formattedCost, size: 16)
        }
        .padding(9)
        .background(DNTheme.Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: DNTheme.Radius.chip, style: .continuous))
    }
}
