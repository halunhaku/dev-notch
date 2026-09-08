import SwiftUI

/// Ultra-compact status view for the MacBook physical notch, displaying the generic Compact Metric.
struct AICompactStatusView: View {
    @ObservedObject var manager: AIProviderManager
    @ObservedObject var screenManager: ScreenManager

    private var metric: AICompactMetric {
        manager.primaryCompactMetric
    }

    private var notchModel: HardwareNotchModel {
        screenManager.notchModel
    }

    var body: some View {
        if notchModel.hasHardwareNotch {
            let screen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
            let totalWidth = NotchGeometry.visualSize(for: .compact, on: screen).width
            let wingWidth = notchModel.leftWingWidth(totalVisualWidth: totalWidth)

            HStack(spacing: 0) {
                // Left Wing: Status indicator dot + Provider Label
                HStack(spacing: 5) {
                    Circle()
                        .fill(metric.severity.color)
                        .frame(width: 5, height: 5)
                        .opacity(0.9)

                    Text(metric.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(width: wingWidth, alignment: .leading)
                .padding(.leading, 12)

                // Center Exclusion Zone: Physical Hardware Notch (Zero content rendered behind camera)
                Color.clear
                    .frame(width: notchModel.hardwareNotchWidth, height: notchModel.hardwareNotchHeight)

                // Right Wing: Metric value & optional secondary
                HStack(spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(metric.severity == .warning ? .orange : (metric.severity == .critical ? .red : .white))
                        .lineLimit(1)

                    if let secondary = metric.secondaryValue {
                        Text(secondary)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .frame(width: wingWidth, alignment: .trailing)
                .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Non-notch / External Display: Classic Virtual Island Layout
            HStack(spacing: 7) {
                Circle()
                    .fill(metric.severity.color)
                    .frame(width: 5, height: 5)
                    .opacity(0.9)

                Text(metric.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                HStack(spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(metric.severity == .warning ? .orange : (metric.severity == .critical ? .red : .white))

                    if let secondary = metric.secondaryValue {
                        Text(secondary)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
