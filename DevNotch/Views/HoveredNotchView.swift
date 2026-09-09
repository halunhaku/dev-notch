import SwiftUI

/// Hovered state providing an interactive dynamic island teaser for the active Primary Provider.
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

    private var quotaSubtitle: String {
        if let secondary = metric.secondaryValue {
            return "\(metric.label): \(metric.value) (\(secondary))"
        } else {
            return "\(metric.label): \(metric.value)"
        }
    }

    var body: some View {
        if notchModel.hasHardwareNotch {
            let screen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
            let totalWidth = NotchGeometry.visualSize(for: .hovered, on: screen).width
            let wingWidth = notchModel.leftWingWidth(totalVisualWidth: totalWidth)

            VStack(spacing: 0) {
                // Top Row: Aligned flush with the physical camera notch
                HStack(spacing: 0) {
                    // Left Wing: Icon Badge + App Title
                    HStack(spacing: 6) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 24, height: 24)
                            .frame(width: 20, height: 20)
                            .clipped()
                            .accessibilityHidden(true)

                        Text("Dev Notch")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: wingWidth, alignment: .leading)
                    .padding(.leading, 12)

                    // Center: Physical Notch Content Exclusion Zone
                    Color.clear
                        .frame(width: notchModel.hardwareNotchWidth, height: notchModel.hardwareNotchHeight)

                    // Right Wing: Status Indicator + Chevron
                    HStack(spacing: 5) {
                        Circle()
                            .fill(metric.severity.color)
                            .frame(width: 5, height: 5)

                        Text(providerManager.primaryStatus.shortDescription)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(metric.severity.color.opacity(0.9))
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: wingWidth, alignment: .trailing)
                    .padding(.trailing, 12)
                }
                .frame(height: notchModel.hardwareNotchHeight)

                // Below-Notch Area: Primary Subtitle completely clear of the physical camera
                HStack(spacing: 8) {
                    hoverNowPlayingLine
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Non-notch / External Displays: Unified Virtual Island Layout
            HStack(spacing: 12) {
                // Icon Badge
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
                    .frame(width: 28, height: 28)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dev Notch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    hoverNowPlayingLine
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

    private var hoverNowPlayingLine: some View {
        HStack(spacing: 6) {
            if nowPlayingStore.info.isPlaying, nowPlayingStore.info.hasTrack {
                Button(action: { nowPlayingStore.togglePlayPause() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("\(nowPlayingStore.info.displayTitle)  ·  \(nowPlayingStore.info.displayArtist)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            } else {
                Text(quotaSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
    }
}
