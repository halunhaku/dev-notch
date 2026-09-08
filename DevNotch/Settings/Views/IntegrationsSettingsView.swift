import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject var manager: AIProviderManager

    var body: some View {
        Form {
            if !AppInstallation.isStable() {
                Text("Move Dev Notch to Applications first.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
            }

            if let error = manager.integrationErrorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }

            // Claude Code Integration
            Section(header: Text("Anthropic Claude Code").font(.headline)) {
                let claudeSnapshot = manager.snapshots[.claude]
                let isInstalled = claudeSnapshot?.isLiveActivityEnabled ?? false

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Claude Code Live Activity")
                            .font(.system(size: 12, weight: .semibold))

                        Text("Receives non-sensitive session telemetry (model, context, working state) via safe settings.json hooks.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(isInstalled ? "Disable" : "Enable") {
                        manager.toggleClaudeLiveActivity()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!isInstalled && !AppInstallation.isStable())
                }

                HStack {
                    Text("Integration Status:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(isInstalled ? "Active (_dev_notch hooks installed)" : "Not Enabled")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isInstalled ? .green : .secondary)
                }
            }

            // Google Antigravity Integration
            Section(header: Text("Google Antigravity").font(.headline)) {
                let agySnapshot = manager.snapshots[.antigravity]
                let isInstalled = agySnapshot?.isLiveActivityEnabled ?? false

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Antigravity Live Activity")
                            .font(.system(size: 12, weight: .semibold))

                        Text("Receives agent working & completed events via ~/.gemini/config/hooks.json without touching secrets.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(isInstalled ? "Disable" : "Enable") {
                        manager.toggleAntigravityLiveActivity()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!isInstalled && !AppInstallation.isStable())
                }

                HStack {
                    Text("Integration Status:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(isInstalled ? "Active (dev-notch-antigravity hooks installed)" : "Not Enabled")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isInstalled ? .green : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(10)
    }
}
