import SwiftUI

/// Displays session cost incurred in the active conversation (API Key users).
struct AISessionCostView: View {
    let cost: AISessionCostMetric

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Session Cost")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Text("Current conversation spend")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            Text(cost.formattedCost)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(9)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
