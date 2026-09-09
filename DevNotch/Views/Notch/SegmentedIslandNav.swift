import SwiftUI

struct SegmentedIslandNav: View {
    @Binding var selection: NotchContentMode
    let modes: [NotchContentMode]
    var onOpenSettings: () -> Void
    var onCollapse: () -> Void

    var body: some View {
        HStack(spacing: DNTheme.Space.control) {
            HStack(spacing: 2) {
                ForEach(modes) { mode in
                    let selected = selection == mode
                    Button {
                        withAnimation(DNTheme.Motion.tabAnimation) {
                            selection = mode
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.systemImage)
                            Text(mode.title)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? DNTheme.Color.textPrimary : DNTheme.Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(DNTheme.Color.accent.opacity(0.14))
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(FullAreaPlainButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(DNTheme.Space.nav)
            .background(DNTheme.Color.navIdle)
            .clipShape(Capsule())

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DNTheme.Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(DNTheme.Color.cardFill)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline)
                    }
            }
            .buttonStyle(.plain)
            .help("Open Settings")

            Button(action: onCollapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DNTheme.Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(DNTheme.Color.cardFill)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(DNTheme.Color.hairline, lineWidth: DNTheme.Space.hairline)
                    }
            }
            .buttonStyle(.plain)
            .help("Collapse Notch")
        }
    }
}

extension NotchContentMode {
    var title: LocalizedStringKey {
        switch self {
        case .ai: "AI"
        case .system: "System"
        case .music: "Music"
        }
    }

    var systemImage: String {
        switch self {
        case .ai: "sparkles"
        case .system: "waveform.path.ecg"
        case .music: "music.note"
        }
    }
}
