import SwiftUI

struct DNCard<Content: View>: View {
    var accentBorder: Color? = nil
    var padding: CGFloat = DNTheme.Space.card
    var fillsHeight: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background(DNTheme.Color.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: DNTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DNTheme.Radius.card, style: .continuous)
                    .stroke(accentBorder ?? DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline)
            }
    }
}

struct DNProgressBar: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = DNTheme.Space.progress

    var body: some View {
        GeometryReader { geo in
            let clamped = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DNTheme.Color.track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * clamped))
            }
        }
        .frame(height: height)
        .animation(DNTheme.Motion.progressAnimation, value: progress)
    }
}

struct DNMetricText: View {
    let text: String
    var size: CGFloat = 28

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(DNTheme.Color.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct DNStatusPill: View {
    let status: AIProviderStatus

    var body: some View {
        let color = DNTheme.statusColor(for: status)
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(LocalizedStringKey(status.shortDescription))
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

struct DNProviderGlyph: View {
    let id: AIProviderID
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DNTheme.Radius.icon, style: .continuous)
                .fill(DNTheme.providerColor(for: id).opacity(0.16))
            Image(systemName: DNTheme.providerSymbol(for: id))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(DNTheme.providerColor(for: id))
        }
        .frame(width: size, height: size)
    }
}

struct DNBadge: View {
    let text: LocalizedStringKey
    var tint: Color = DNTheme.Color.accent

    var body: some View {
        Text(text)
            .font(DNTheme.Typeface.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

/// macOS `.plain` only hits glyph/text; this makes the whole label frame tappable.
struct FullAreaPlainButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onTapGesture(perform: configuration.trigger)
    }
}
