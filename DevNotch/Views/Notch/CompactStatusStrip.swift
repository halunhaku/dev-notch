import SwiftUI

/// Compact / hovered information pill. Used for non-notch displays and as the
/// below-notch strip on hardware-notch hover. Hardware compact stays wing-only.
struct CompactStatusStrip: View {
    @ObservedObject var providerManager: AIProviderManager
    @ObservedObject var nowPlayingStore: NowPlayingStore
    var showsAppTitle: Bool = true
    var showsChevron: Bool = true

    private var metric: AICompactMetric {
        providerManager.primaryCompactMetric
    }

    var body: some View {
        HStack(spacing: 5) {
            if showsAppTitle {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .accessibilityHidden(true)

                Text("Dev Notch")
                    .font(DNTheme.Typeface.compact)
                    .foregroundStyle(DNTheme.Color.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(2)
            }

            pillDivider
            quotaChip
                .layoutPriority(1)

            if nowPlayingStore.info.isPlaying, nowPlayingStore.info.hasTrack {
                pillDivider
                musicChip
                    .layoutPriority(0)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(metric.severity.color)
                .frame(width: 6, height: 6)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DNTheme.Color.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var quotaChip: some View {
        let snapshot = providerManager.primarySnapshot
        return HStack(spacing: 4) {
            Image(systemName: DNTheme.providerSymbol(for: providerManager.activePrimaryID))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DNTheme.providerColor(for: providerManager.activePrimaryID))
            Text(snapshot?.displayName ?? metric.label)
                .font(DNTheme.Typeface.compact)
                .foregroundStyle(DNTheme.Color.textPrimary)
                .lineLimit(1)
            Text(metric.value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(metricValueColor)
                .lineLimit(1)
        }
    }

    private var musicChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DNTheme.Color.accent)
            Text(nowPlayingStore.info.displayTitle)
                .font(DNTheme.Typeface.compact)
                .foregroundStyle(DNTheme.Color.textSecondary)
                .lineLimit(1)
        }
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(DNTheme.Color.hairline)
            .frame(width: DNTheme.Space.hairline, height: 12)
    }

    private var metricValueColor: Color {
        switch metric.severity {
        case .warning: return DNTheme.Color.warning
        case .critical: return DNTheme.Color.critical
        default: return DNTheme.Color.textPrimary
        }
    }
}
