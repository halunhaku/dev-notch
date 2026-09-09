import SwiftUI

/// Root visual container for Dev Notch, managing the black island shape,
/// inner hairline, generic Task Pulse, and state transitions.
struct NotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var providerManager: AIProviderManager
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var systemMetricsStore: SystemMetricsStore
    @ObservedObject var nowPlayingStore: NowPlayingStore
    var onOpenSettings: (() -> Void)? = nil

    private var activeScreen: NSScreen {
        screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var visualSize: CGSize {
        NotchGeometry.visualSize(for: model.state, on: activeScreen)
    }

    private var cornerRadius: CGFloat {
        NotchGeometry.cornerRadius(for: model.state)
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // No drop shadow: radius blurs left/right and reads as a faint black rim.
                notchShape
                    .fill(DNTheme.Color.island)
                    .overlay {
                        notchShape
                            .strokeBorder(DNTheme.Color.islandStroke, lineWidth: DNTheme.Space.hairline)
                    }

                Group {
                    switch model.state {
                    case .compact:
                        CompactNotchView(
                            screenManager: screenManager,
                            providerManager: providerManager,
                            nowPlayingStore: nowPlayingStore
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    case .hovered:
                        HoveredNotchView(
                            model: model,
                            screenManager: screenManager,
                            providerManager: providerManager,
                            nowPlayingStore: nowPlayingStore
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                    case .expanded:
                        ExpandedNotchView(
                            model: model,
                            screenManager: screenManager,
                            providerManager: providerManager,
                            preferences: preferences,
                            systemMetricsStore: systemMetricsStore,
                            nowPlayingStore: nowPlayingStore,
                            onOpenSettings: onOpenSettings
                        )
                        .transition(.opacity)
                    }
                }

                VStack {
                    Spacer()
                    TaskPulseView(
                        state: providerManager.activePrimaryActivityState,
                        isTransientDone: providerManager.activePrimaryIsTransientDone
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 2)
                }
            }
            .frame(width: visualSize.width, height: visualSize.height)
            .contentShape(notchShape)
            .onHover { isHovered in
                model.handleHover(isHovered)
            }
            .modifier(NotchCompactTapModifier(enabled: model.state != .expanded) {
                model.handleTap()
            })

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .environment(\.locale, preferences.resolvedLocale)
        .animation(DNTheme.Motion.notchAnimation, value: model.state)
        .animation(DNTheme.Motion.tabAnimation, value: model.contentMode)
    }
}

private struct NotchCompactTapModifier: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}
