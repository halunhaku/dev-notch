import SwiftUI

/// Expanded dashboard shell: title, segmented nav, and tab content.
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
        VStack(alignment: .leading, spacing: DNTheme.Space.control) {
            dashboardToolbar

            activePage
                .id(selectedContentMode)
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, DNTheme.Space.page)
        .padding(.top, notchModel.contentTopInset + 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dashboardToolbar: some View {
        HStack(spacing: 12) {
            brandCluster
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            SegmentedIslandNav(
                selection: Binding(
                    get: { selectedContentMode },
                    set: { model.contentMode = $0 }
                ),
                modes: availableContentModes,
                onOpenSettings: openSettingsWindow,
                onCollapse: { model.collapseToCompact() }
            )
            .frame(maxWidth: 440)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var activePage: some View {
        switch selectedContentMode {
        case .ai:
            ScrollView(.vertical) {
                AIDashboardView(manager: providerManager)
                    .padding(.bottom, 2)
            }
            .scrollIndicators(.never)
        case .system:
            SystemInsightsView(store: systemMetricsStore, isVisible: true)
        case .music:
            NowPlayingView(store: nowPlayingStore)
        }
    }

    private var brandCluster: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .accessibilityHidden(true)

            Text("Dev Notch")
                .font(DNTheme.Typeface.pageTitle)
                .foregroundStyle(DNTheme.Color.textPrimary)
                .lineLimit(1)

            Text("v\(versionString)")
                .font(DNTheme.Typeface.badge)
                .foregroundStyle(DNTheme.Color.textTertiary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DNTheme.Color.cardFill)
                .clipShape(Capsule())
        }
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

    private func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
        onOpenSettings?()
    }
}
