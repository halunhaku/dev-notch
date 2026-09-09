import SwiftUI

struct SecondaryProviderCard: View {
    let snapshot: AIProviderSnapshot

    private var remaining: Double? { snapshot.primaryRemainingPercent }
    private var caption: String {
        if let secondary = snapshot.compactMetric.secondaryValue, !secondary.isEmpty {
            return secondary
        }
        if let source = snapshot.credentialSource {
            return source
        }
        return snapshot.compactMetric.value
    }

    var body: some View {
        DNCard(padding: DNTheme.Space.cardCompact) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    DNProviderGlyph(id: snapshot.id, size: 20)
                    Text(snapshot.displayName)
                        .font(DNTheme.Typeface.compact)
                        .foregroundStyle(DNTheme.Color.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    DNStatusPill(status: snapshot.status)
                }

                DNMetricText(
                    text: remaining.map { "\(Int(round($0)))%" } ?? snapshot.compactMetric.value,
                    size: 16
                )

                Text(caption)
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
                    .lineLimit(1)

                if let remaining {
                    DNProgressBar(
                        progress: remaining / 100.0,
                        tint: DNTheme.quotaTint(
                            remainingPercent: remaining,
                            brand: DNTheme.Color.success
                        ),
                        height: DNTheme.Space.progressCompact
                    )
                } else {
                    DNProgressBar(
                        progress: 0,
                        tint: DNTheme.Color.track,
                        height: DNTheme.Space.progressCompact
                    )
                    .opacity(0.35)
                }
            }
        }
    }
}
