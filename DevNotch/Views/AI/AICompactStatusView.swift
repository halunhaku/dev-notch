import SwiftUI

/// Ultra-compact status view designed specifically for the MacBook physical notch.
struct AICompactStatusView: View {
    @ObservedObject var manager: AIProviderManager

    private var statusColor: Color {
        switch manager.status {
        case .ready: return Color.green
        case .checking: return Color.cyan
        case .notAuthenticated: return Color.orange
        case .notInstalled, .unavailable, .error: return Color.red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Left Indicator Dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .opacity(0.9)

            Spacer()

            // Right Info: Remaining Quota or Developer Glyph
            if manager.status == .ready, let remaining = manager.primaryRemainingInt {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.9))

                    Text("\(remaining)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
