import SwiftUI

/// Elegant monetary balance view for AI API providers (e.g. DeepSeek).
struct AIBalanceView: View {
    let balance: AIBalance

    private var availabilityColor: Color {
        balance.isAvailable ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Label & Availability
            HStack {
                Text("Account Balance (\(balance.currency))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))

                Spacer()

                HStack(spacing: 3) {
                    Circle()
                        .fill(availabilityColor)
                        .frame(width: 4, height: 4)

                    Text(balance.isAvailable ? "Available" : "Unavailable")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(availabilityColor.opacity(0.9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(availabilityColor.opacity(0.12))
                .clipShape(Capsule())
            }

            // Primary Total Balance
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(balance.formattedTotal)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(balance.isAvailable ? .white : .red.opacity(0.9))

                Spacer()
            }

            // Sub-details: Top-up vs Granted Breakdown
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Text("Top-up:")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    Text(balance.formattedToppedUp)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                HStack(spacing: 3) {
                    Text("Granted:")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                    Text(balance.formattedGranted)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
