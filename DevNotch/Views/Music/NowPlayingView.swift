import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var store: NowPlayingStore

    var body: some View {
        Group {
            if store.info.hasTrack {
                NowPlayingPanel(store: store)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(DNTheme.Color.textMuted)
            Text("Nothing playing")
                .font(DNTheme.Typeface.sectionTitle)
                .foregroundStyle(DNTheme.Color.textSecondary)
            Text("Apple Music, Spotify, and other Now Playing apps appear here.")
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(MusicLayout.cardPadding)
        .background(DNTheme.Color.cardFill)
        .clipShape(MusicLayout.cardShape)
        .overlay {
            MusicLayout.cardShape.stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline)
        }
    }

    static func formatClock(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
