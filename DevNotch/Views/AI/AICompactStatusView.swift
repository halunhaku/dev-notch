import SwiftUI

/// Ultra-compact status view for the MacBook physical notch, showing the active Primary Provider.
struct AICompactStatusView: View {
    @ObservedObject var manager: AIProviderManager

    private var statusColor: Color {
        switch manager.primaryStatus {
        case .ready: return Color.green
        case .checking: return Color.cyan
        case .notAuthenticated: return Color.orange
        case .notInstalled, .unavailable, .error: return Color.red
        }
    }

    private var isLowQuota: Bool {
        if let remaining = manager.primaryRemainingInt, remaining < 20 {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 7) {
            // Left Indicator Dot
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
                .opacity(0.9)

            Spacer()

            // Right Info: Primary Provider Name & Remaining Quota
            if manager.primaryStatus == .ready, let remaining = manager.primaryRemainingInt {
                HStack(spacing: 3) {
                    Text(manager.primaryDisplayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Text("\(remaining)%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(isLowQuota ? .orange : .white)
                }
            } else {
                HStack(spacing: 3) {
                    Text(manager.primaryDisplayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
