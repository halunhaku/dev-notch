import SwiftUI

/// Hovered state providing an interactive dynamic island teaser for the active Primary Provider.
struct HoveredNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var providerManager: AIProviderManager

    private var metric: AICompactMetric {
        providerManager.primaryCompactMetric
    }

    private var quotaSubtitle: String {
        if let secondary = metric.secondaryValue {
            return "\(metric.label): \(metric.value) (\(secondary))"
        } else {
            return "\(metric.label): \(metric.value)"
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
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            // Status Indicator & Chevron
            HStack(spacing: 5) {
                Circle()
                    .fill(metric.severity.color)
                    .frame(width: 6, height: 6)

                Text(providerManager.primaryStatus.shortDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(metric.severity.color.opacity(0.9))

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
