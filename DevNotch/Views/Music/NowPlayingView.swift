import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var store: NowPlayingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text("Now Playing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Circle()
                    .fill(store.info.isPlaying ? Color.green : Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
                Text(store.info.isPlaying ? "Playing" : (store.info.hasTrack ? "Paused" : "Idle"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if store.info.hasTrack {
                Spacer(minLength: 4)
                playerCard
                Spacer(minLength: 4)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.28))
                    Text("Nothing playing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Apple Music, Spotify, and other Now Playing apps appear here.")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.32))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var playerCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                artwork
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.info.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(store.info.displayArtist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    if !store.info.album.isEmpty {
                        Text(store.info.album)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            progressRow

            HStack(spacing: 22) {
                Spacer()
                controlButton("backward.fill", size: 13) { store.previousTrack() }
                controlButton(store.info.isPlaying ? "pause.fill" : "play.fill", size: 17, prominent: true) {
                    store.togglePlayPause()
                }
                controlButton("forward.fill", size: 13) { store.nextTrack() }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        }
    }

    private var artwork: some View {
        Group {
            if let data = store.info.artworkData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var progressRow: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = store.info.currentElapsed(at: context.date)
            let duration = store.info.duration
            let progress = duration > 0 ? min(1, max(0, elapsed / duration)) : 0
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(Color.cyan.opacity(0.9))
                            .frame(width: max(5, geo.size.width * progress))
                    }
                }
                .frame(height: 5)
                HStack {
                    Text(Self.formatClock(elapsed))
                    Spacer()
                    Text(duration > 0 ? Self.formatClock(duration) : "--:--")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
            }
        }
    }

    private func controlButton(_ systemName: String, size: CGFloat, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: prominent ? 40 : 30, height: prominent ? 40 : 30)
                .background(Color.white.opacity(prominent ? 0.18 : 0.08))
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    static func formatClock(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
