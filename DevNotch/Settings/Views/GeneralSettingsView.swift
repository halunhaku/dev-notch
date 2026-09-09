import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    var onShortcutChanged: ((KeyboardShortcutDefinition) -> Void)? = nil

    private var isSystemReduceMotionActive: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        Form {
            // Startup Section
            Section(header: Text("Startup").font(.headline)) {
                Toggle("Launch Dev Notch at login", isOn: $preferences.launchAtLogin)
                    .disabled(!preferences.launchAtLogin && !AppInstallation.isStable())

                if !AppInstallation.isStable() {
                    Text("Move Dev Notch to Applications first.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }

                if let error = preferences.launchAtLoginError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }

            // Interface Section
            Section(header: Text("Interface").font(.headline)) {
                Toggle("Show menu bar icon", isOn: $preferences.showMenuBarItem)
                Toggle("Enable Task Pulse horizon animation", isOn: $preferences.taskPulseEnabled)
                Toggle("Enable System Insights", isOn: $preferences.systemInsightsEnabled)

                Text("CPU, memory, network, battery, and thermal metrics are sampled only while the System page is visible.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)


                if isSystemReduceMotionActive {
                    HStack {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("System Reduce Motion is On (pulse is rendered as a steady horizon glow)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Show completed state flash", isOn: $preferences.showCompletedActivity)

                if preferences.showCompletedActivity {
                    Picker("Completed display duration:", selection: $preferences.completedDisplayDuration) {
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds (default)").tag(3.0)
                        Text("5 seconds").tag(5.0)
                    }
                    .pickerStyle(.menu)
                }
            }

            // Global Shortcut Section
            Section(header: Text("Global Shortcut").font(.headline)) {
                Toggle("Enable global shortcut", isOn: $preferences.globalHotkeyEnabled)

                if preferences.globalHotkeyEnabled {
                    HStack {
                        Text("Toggle Dev Notch:")
                        Spacer()
                        ShortcutRecorderView(shortcut: $preferences.globalHotkey, onChange: onShortcutChanged)
                    }

                    Text("Press shortcut from any app to toggle between Compact and Expanded states.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(10)
    }
}
