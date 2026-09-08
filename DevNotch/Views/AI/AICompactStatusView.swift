import SwiftUI

/// Ultra-compact status view for the MacBook physical notch, displaying the generic Compact Metric.
struct AICompactStatusView: View {
    @ObservedObject var manager: AIProviderManager

    private var metric: AICompactMetric {
        manager.primaryCompactMetric
    }

    var body: some View {
        HStack(spacing: 7) {
            // Left Status Dot
            Circle()
                .fill(metric.severity.color)
                .frame(width: 5, height: 5)
                .opacity(0.9)

            Spacer()

            // Right Info: Label and Formatted Metric Value
            HStack(spacing: 4) {
                Text(metric.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

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
