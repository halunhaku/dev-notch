import SwiftUI

struct ProviderDetailSheet: View {
    let id: AIProviderID
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var manager: AIProviderManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var openCodeInputKey: String = ""

    private var snapshot: AIProviderSnapshot? {
        manager.snapshots[id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNTheme.Space.section) {
            HStack(spacing: 10) {
                Image(systemName: DNTheme.providerSymbol(for: id))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DNTheme.providerColor(for: id))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(id.displayName)
                        .font(.headline)
                    if let source = snapshot?.credentialSource {
                        Text(source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            if let snapshot {
                LabeledContent("Status", value: L10n.key(snapshot.status.shortDescription, locale: locale))
                LabeledContent("Metric", value: snapshot.compactMetric.value)
            }

            Divider()

            if id == .openCodeGo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        SecureField("OpenCode Go API Key / Token", text: $openCodeInputKey)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            preferences.setOpenCodeApiKey(openCodeInputKey)
                            manager.refresh(providerID: .openCodeGo)
                        }
                        .disabled(openCodeInputKey.isEmpty)
                        if !preferences.openCodeApiKey.isEmpty {
                            Button("Clear") {
                                openCodeInputKey = ""
                                preferences.setOpenCodeApiKey("")
                                manager.refresh(providerID: .openCodeGo)
                            }
                        }
                    }
                    Button("Run 'opencode auth login' in Terminal") {
                        openTerminalLogin()
                    }
                    .buttonStyle(.link)
                }
            }

            if [.grok, .codex, .claude].contains(id) {
                Button {
                    manager.signIn(providerID: id)
                } label: {
                    Label(signInLabel, systemImage: "terminal")
                }
            }

            HStack {
                Button("Refresh") {
                    manager.refresh(providerID: id)
                }
                Spacer()
                if preferences.isProviderEnabled(id), preferences.preferredPrimaryProviderID != id {
                    Button("Set as Primary") {
                        preferences.preferredPrimaryProviderID = id
                        manager.setPrimaryProvider(id)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 420, height: 320)
        .onAppear {
            openCodeInputKey = preferences.openCodeApiKey
        }
    }

    private var signInLabel: String {
        switch id {
        case .grok: return "Sign in with `grok login --oauth`"
        case .codex: return "Sign in with `codex login`"
        case .claude: return "Sign in with `claude auth login`"
        default: return "Sign in"
        }
    }

    private func openTerminalLogin() {
        let script = "tell application \"Terminal\" to do script \"opencode auth login\" activate"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
