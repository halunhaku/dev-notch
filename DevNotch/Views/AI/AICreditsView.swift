import SwiftUI

/// Simple metric row displaying API credit balance or unlimited status.
struct AICreditsView: View {
    let credits: AICredits

    var body: some View {
        HStack {
            Text("API Credits")
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.textTertiary)
            Spacer()
            Text(credits.balance ?? (credits.unlimited ? "Unlimited" : "Active"))
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DNTheme.Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: DNTheme.Radius.chip, style: .continuous))
    }
}
