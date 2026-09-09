import SwiftUI

/// Hovered state: single-row compact strip. Hardware notch keeps camera exclusion.
struct HoveredNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var providerManager: AIProviderManager
    @ObservedObject var nowPlayingStore: NowPlayingStore

    private var metric: AICompactMetric {
        providerManager.primaryCompactMetric
    }

    private var notchModel: HardwareNotchModel {
        screenManager.notchModel
    }

    var body: some View {
        if notchModel.hasHardwareNotch {
            hardwareHover
        } else {
            CompactStatusStrip(
                providerManager: providerManager,
                nowPlayingStore: nowPlayingStore,
                showsAppTitle: true,
                showsChevron: true
            )
        }
    }

    private var hardwareHover: some View {
        let screen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
        let totalWidth = NotchGeometry.visualSize(for: .hovered, on: screen).width
        let wingWidth = notchModel.leftWingWidth(totalVisualWidth: totalWidth)
        let playing = nowPlayingStore.info.isPlaying && nowPlayingStore.info.hasTrack

        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .accessibilityHidden(true)
                Text("Dev Notch")
                    .font(DNTheme.Typeface.compact)
                    .foregroundStyle(DNTheme.Color.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: wingWidth, alignment: .leading)
            .padding(.leading, 12)

            Color.clear
                .frame(width: notchModel.hardwareNotchWidth, height: notchModel.hardwareNotchHeight)

            HStack(spacing: 5) {
                if playing {
                    Image(systemName: "music.note")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DNTheme.Color.accent)
                }
                Text(metric.value)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DNTheme.Color.textPrimary)
                    .lineLimit(1)
                Circle()
                    .fill(metric.severity.color)
                    .frame(width: 5, height: 5)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DNTheme.Color.textTertiary)
            }
            .frame(width: wingWidth, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
