import SwiftUI

/// Simple metric row displaying API credit balance or unlimited status.
struct AICreditsView: View {
    let credits: AICredits

    var body: some View {
        HStack {
            Text("API Credits")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text(credits.balance ?? (credits.unlimited ? "Unlimited" : "Active"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
