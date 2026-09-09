import SwiftUI

/// Expanded state displaying the multi-provider dashboard in Dev Notch.
struct ExpandedNotchView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var providerManager: AIProviderManager
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var systemMetricsStore: SystemMetricsStore
    @ObservedObject var nowPlayingStore: NowPlayingStore
    var onOpenSettings: (() -> Void)? = nil

    private var versionString: String {
        BundleVersion.marketingVersion(infoDictionary: Bundle.main.infoDictionary ?? [:]) ?? "Unknown"
    }

    private var notchModel: HardwareNotchModel {
        screenManager.notchModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if notchModel.hasHardwareNotch {
                let screen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
                let totalWidth = NotchGeometry.visualSize(for: .expanded, on: screen).width
                let wingWidth = notchModel.leftWingWidth(totalVisualWidth: totalWidth)

                // Top Row: Wings on Left and Right of the physical camera notch
                HStack(spacing: 0) {
                    // Left Wing: App Logo, Title & Version
                    HStack(spacing: 6) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 24, height: 24)
                            .frame(width: 20, height: 20)
                            .clipped()
                            .accessibilityHidden(true)

                        Text("Dev Notch")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)

                        Text("v\(versionString)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .frame(width: wingWidth, alignment: .leading)
                    .padding(.leading, 12)

                    // Center: Physical Hardware Notch Exclusion Zone
                    Color.clear
                        .frame(width: notchModel.hardwareNotchWidth, height: notchModel.hardwareNotchHeight)

                    // Right Wing: Settings Button & Collapse Button
                    HStack(spacing: 6) {
                        Button(action: {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                            openSettings()
                            onOpenSettings?()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings")

                        Button(action: {
                            model.collapseToCompact()
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Collapse Notch")
                    }
                    .frame(width: wingWidth, alignment: .trailing)
                    .padding(.trailing, 12)
                }
                .frame(height: notchModel.hardwareNotchHeight)
            } else {
                // Virtual Island: Unconstrained Top Row
                HStack {
                    HStack(spacing: 8) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 29, height: 29)
                            .frame(width: 24, height: 24)
                            .clipped()
                            .accessibilityHidden(true)

                        Text("Dev Notch")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        Text("v\(versionString)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Button(action: {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                            openSettings()
                            onOpenSettings?()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings")

                        Button(action: {
                            model.collapseToCompact()
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Collapse Notch")
                    }
                }
                .padding(.top, 4)
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            if availableContentModes.count > 1 {
                contentModePicker
            }

            ZStack(alignment: .top) {
                aiDashboard
                    .opacity(selectedContentMode == .ai ? 1 : 0)
                    .allowsHitTesting(selectedContentMode == .ai)
                    .accessibilityHidden(selectedContentMode != .ai)

                SystemInsightsView(store: systemMetricsStore, isVisible: selectedContentMode == .system)
                    .opacity(selectedContentMode == .system ? 1 : 0)
                    .allowsHitTesting(selectedContentMode == .system)
                    .accessibilityHidden(selectedContentMode != .system)

                NowPlayingView(store: nowPlayingStore)
                    .opacity(selectedContentMode == .music ? 1 : 0)
                    .allowsHitTesting(selectedContentMode == .music)
                    .accessibilityHidden(selectedContentMode != .music)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var availableContentModes: [NotchContentMode] {
        var modes: [NotchContentMode] = [.ai, .music]
        if preferences.systemInsightsEnabled {
            modes.insert(.system, at: 1)
        }
        return modes
    }

    private var selectedContentMode: NotchContentMode {
        availableContentModes.contains(model.contentMode) ? model.contentMode : .ai
    }

    private var contentModePicker: some View {
        HStack(spacing: 3) {
            ForEach(availableContentModes) { mode in
                let selected = selectedContentMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        model.contentMode = mode
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.systemImage)
                        Text(mode.title)
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(selected ? Color.white.opacity(0.13) : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(FullAreaPlainButtonStyle())
                .frame(maxWidth: .infinity)
                .contentShape(Capsule())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.055))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var aiDashboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)

                Text("AI Status Center")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Text("\(providerManager.enabledProviderIDs.count) Active")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(providerManager.enabledProviderIDs, id: \.self) { id in
                        if let snapshot = providerManager.snapshots[id] {
                            AIProviderCard(
                                snapshot: snapshot,
                                isPrimary: id == providerManager.preferredPrimaryID,
                                onSetPrimary: {
                                    providerManager.setPrimaryProvider(id)
                                },
                                onRefresh: {
                                    providerManager.refresh(providerID: id)
                                },
                                onToggleLiveActivity: (id == .claude || id == .antigravity) ? {
                                    if id == .claude {
                                        providerManager.toggleClaudeLiveActivity()
                                    } else {
                                        providerManager.toggleAntigravityLiveActivity()
                                    }
                                } : nil,
                                onSignIn: [.grok, .codex, .claude].contains(id) ? {
                                    providerManager.signIn(providerID: id)
                                } : nil
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Text("Click ★ to set Primary • Tap outside or Esc to collapse")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension NotchContentMode {
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

/// macOS `.plain` only hits glyph/text; this makes the whole label frame tappable.
private struct FullAreaPlainButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onTapGesture(perform: configuration.trigger)
    }
}
