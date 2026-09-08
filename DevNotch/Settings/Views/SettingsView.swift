import SwiftUI

/// Root Settings window view organizing tabs into General, Providers, Integrations, and About.
struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var manager: AIProviderManager
    var onShortcutChanged: ((KeyboardShortcutDefinition) -> Void)? = nil

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences, onShortcutChanged: onShortcutChanged)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ProvidersSettingsView(preferences: preferences, manager: manager)
                .tabItem {
                    Label("AI Providers", systemImage: "cpu")
                }

            IntegrationsSettingsView(manager: manager)
                .tabItem {
                    Label("Integrations", systemImage: "puzzlepiece.extension")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
    }
}
