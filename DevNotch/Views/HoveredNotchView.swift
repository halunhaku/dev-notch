import SwiftUI

/// Hovered state providing an interactive dynamic island teaser.
struct HoveredNotchView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        HStack(spacing: 12) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 28, height: 28)

                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.cyan)
            }

            // Title & Action Hint
            VStack(alignment: .leading, spacing: 2) {
                Text("Dev Notch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text("Click to open")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Status Indicator & Chevron
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("Ready")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green.opacity(0.9))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
