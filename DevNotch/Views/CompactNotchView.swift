import SwiftUI

/// Compact display state. Hardware notch stays wing-only; virtual island uses the info pill.
struct CompactNotchView: View {
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var providerManager: AIProviderManager
    @ObservedObject var nowPlayingStore: NowPlayingStore

    var body: some View {
        if screenManager.notchModel.hasHardwareNotch {
            AICompactStatusView(manager: providerManager, screenManager: screenManager)
        } else {
            CompactStatusStrip(
                providerManager: providerManager,
                nowPlayingStore: nowPlayingStore,
                showsAppTitle: true,
                showsChevron: true
            )
        }
    }
}
