import SwiftUI

/// Compact display state matching the physical MacBook notch.
struct CompactNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager

    var body: some View {
        HStack(spacing: 8) {
            // Left micro-indicator: Active Status Dot
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(0.85)

            Spacer()

            // Right micro-indicator: Developer Glyph
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
