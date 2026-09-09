import SwiftUI

struct NowPlayingPanel: View {
    @ObservedObject var store: NowPlayingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                ArtworkView(data: store.info.artworkData, size: MusicLayout.artwork)
                VStack(alignment: .leading, spacing: 10) {
                    MusicMetadataView(info: store.info)
                    MusicSourceChips(info: store.info) {
                        store.openSourceApp()
                    }
                    MusicProgressView(store: store)
                    MusicPlaybackControlsView(store: store)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            MusicAudioControlBar(store: store)
        }
        .padding(MusicLayout.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DNTheme.Color.cardFill)
        .clipShape(MusicLayout.cardShape)
        .overlay {
            MusicLayout.cardShape.stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline)
        }
    }
}

struct ArtworkView: View {
    let data: Data?
    var size: CGFloat

    var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    DNTheme.Color.cardHover
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.2, weight: .semibold))
                        .foregroundStyle(DNTheme.Color.textMuted)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: MusicLayout.artworkCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MusicLayout.artworkCorner, style: .continuous)
                .stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline)
        }
    }
}

struct MusicMetadataView: View {
    let info: NowPlayingInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Now Playing")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DNTheme.Color.accent)
            Text(info.displayTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DNTheme.Color.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(info.displayArtist)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DNTheme.Color.textSecondary)
                .lineLimit(1)
            if !info.album.isEmpty {
                Text(info.album)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DNTheme.Color.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

struct MusicSourceChips: View {
    let info: NowPlayingInfo
    let onOpenSource: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if !info.sourceAppName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 9, weight: .bold))
                    Text("From \(info.sourceAppName)")
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DNTheme.Color.cardHover)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .onTapGesture(perform: onOpenSource)
            }
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 9, weight: .bold))
                Text("Universal Control")
                    .lineLimit(1)
            }
            .font(DNTheme.Typeface.caption)
            .foregroundStyle(DNTheme.Color.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DNTheme.Color.cardFill)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline) }
        }
    }
}

struct MusicProgressView: View {
    @ObservedObject var store: NowPlayingStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = store.info.currentElapsed(at: context.date)
            let duration = store.info.duration
            let progress = duration > 0 ? min(1, max(0, elapsed / duration)) : 0
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DNTheme.Color.track)
                        Capsule()
                            .fill(DNTheme.Color.accent)
                            .frame(width: max(8, geo.size.width * progress))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .offset(x: max(0, geo.size.width * progress - 5))
                    }
                }
                .frame(height: 10)
                HStack {
                    Text(NowPlayingView.formatClock(elapsed))
                    Spacer()
                    Text(duration > 0 ? NowPlayingView.formatClock(duration) : "--:--")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DNTheme.Color.textTertiary)
            }
        }
    }
}

struct MusicPlaybackControlsView: View {
    @ObservedObject var store: NowPlayingStore

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            MusicCircleButton(systemName: "backward.fill", size: MusicLayout.skipButton) {
                store.previousTrack()
            }
            Image(systemName: store.info.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DNTheme.Color.textPrimary)
                .frame(width: MusicLayout.playButton, height: MusicLayout.playButton)
                .background(DNTheme.Color.accent)
                .clipShape(Circle())
                .shadow(color: DNTheme.Motion.reduceMotion ? .clear : DNTheme.Color.accentGlow, radius: 8)
                .contentShape(Circle())
                .onTapGesture { store.togglePlayPause() }
                .accessibilityLabel(store.info.isPlaying ? "Pause" : "Play")
            MusicCircleButton(systemName: "forward.fill", size: MusicLayout.skipButton) {
                store.nextTrack()
            }
            Spacer()
        }
    }
}

struct MusicAudioControlBar: View {
    @ObservedObject var store: NowPlayingStore

    var body: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(DNTheme.Color.hairline)
                .frame(height: DNTheme.Space.hairline)
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DNTheme.Color.textSecondary)
                GeometryReader { geo in
                    let progress = min(1, max(0, store.volume))
                    ZStack(alignment: .leading) {
                        Capsule().fill(DNTheme.Color.track)
                        Capsule()
                            .fill(DNTheme.Color.accent)
                            .frame(width: max(8, geo.size.width * progress))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .offset(x: max(0, geo.size.width * progress - 5))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            store.setVolume(min(1, max(0, value.location.x / max(geo.size.width, 1))))
                        }
                    )
                }
                .frame(height: 16)
                .frame(maxWidth: 280)
                Spacer(minLength: 8)
                sourceDeviceChip
                if !store.info.sourceBundleIdentifier.isEmpty {
                    openSourceButton
                }
            }
        }
    }

    private var sourceDeviceChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "hifispeaker")
                .font(.system(size: 10, weight: .semibold))
            Text(store.outputDeviceName ?? "System Output")
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .font(DNTheme.Typeface.caption)
        .foregroundStyle(DNTheme.Color.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DNTheme.Color.cardHover)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline) }
    }

    private var openSourceButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 10, weight: .semibold))
            Text("Open in Source App")
                .lineLimit(1)
        }
        .font(DNTheme.Typeface.caption)
        .foregroundStyle(DNTheme.Color.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DNTheme.Color.cardHover)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture { store.openSourceApp() }
    }
}

struct MusicCircleButton: View {
    let systemName: String
    var size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(DNTheme.Color.textPrimary)
            .frame(width: size, height: size)
            .background(Circle().fill(hovering ? DNTheme.Color.cardHover : Color.white.opacity(0.08)))
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .scaleEffect(hovering && !DNTheme.Motion.reduceMotion ? 1.04 : 1)
            .onHover { hovering = $0 }
            .animation(MusicLayout.hoverAnimation, value: hovering)
    }
}
