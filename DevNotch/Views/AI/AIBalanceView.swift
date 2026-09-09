import SwiftUI

/// Elegant monetary balance view for AI API providers (e.g. DeepSeek).
struct AIBalanceView: View {
    let balance: AIBalance

    private var availabilityColor: Color {
        balance.isAvailable ? DNTheme.Color.success : DNTheme.Color.critical
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Account Balance (\(balance.currency))")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(availabilityColor)
                        .frame(width: 4, height: 4)
                    Text(balance.isAvailable ? "Available" : "Unavailable")
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(availabilityColor)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(availabilityColor.opacity(0.12))
                .clipShape(Capsule())
            }

            DNMetricText(text: balance.formattedTotal, size: 20)

            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Text("Top-up:")
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    Text(balance.formattedToppedUp)
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textSecondary)
                }
                HStack(spacing: 3) {
                    Text("Granted:")
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    Text(balance.formattedGranted)
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textSecondary)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(DNTheme.Color.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: DNTheme.Radius.chip, style: .continuous))
    }
}
