import SwiftUI

/// Hovered state providing an interactive dynamic island teaser with real AI quota.
struct HoveredNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var providerManager: AIProviderManager

    private var quotaSubtitle: String {
        if providerManager.status == .ready, let remaining = providerManager.primaryRemainingInt {
            return "\(providerManager.activeProviderID.displayName): \(remaining)% remaining"
        } else {
            return providerManager.statusTitle
        }
    }

    private var statusBadgeColor: Color {
        switch providerManager.status {
        case .ready: return Color.green
        case .checking: return Color.cyan
        case .notAuthenticated: return Color.orange
        case .notInstalled, .unavailable, .error: return Color.red
        }
    }

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

            // Title & Quota Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text("Dev Notch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(quotaSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Status Indicator & Chevron
            HStack(spacing: 5) {
                Circle()
                    .fill(statusBadgeColor)
                    .frame(width: 6, height: 6)

                Text(providerManager.statusTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusBadgeColor.opacity(0.9))

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
