import SwiftUI

/// Progress bar and indicator for active conversation Context Window.
struct AIContextView: View {
    let context: AIContextMetric

    private var fillGradient: LinearGradient {
        let used = context.usedPercent
        if used > 90 {
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        } else if used > 70 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header: Title & Used %
            HStack {
                Text("Context Window")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(context.formattedPercentage)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Progress Bar Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(fillGradient)
                        .frame(
                            width: max(0, min(geo.size.width, geo.size.width * CGFloat(context.usedPercent / 100.0))),
                            height: 6
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: context.usedPercent)
                }
            }
            .frame(height: 6)

            // Sub-row: Remaining percentage
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.4))

                Text("\(context.formattedRemaining) in current session")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
        }
        .padding(9)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
