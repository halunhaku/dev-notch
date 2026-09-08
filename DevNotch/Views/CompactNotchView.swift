import SwiftUI

/// Compact display state matching the physical MacBook notch, displaying live AI quota.
struct CompactNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var providerManager: AIProviderManager

    var body: some View {
        AICompactStatusView(manager: providerManager)
    }
}
