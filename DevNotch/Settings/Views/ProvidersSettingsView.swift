import SwiftUI

struct ProvidersSettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var manager: AIProviderManager
    @State private var openCodeInputKey: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configure which AI providers are active and select your preferred primary provider. Drag rows to reorder; the expanded AI dashboard uses the same order.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            List {
                ForEach(manager.providerIDs, id: \.self) { id in
                    let isEnabled = preferences.isProviderEnabled(id)
                    let isPrimary = preferences.preferredPrimaryProviderID == id
                    let snapshot = manager.snapshots[id]

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            // Enable/Disable Toggle
                            Toggle("", isOn: Binding(
                                get: { preferences.isProviderEnabled(id) },
                                set: { preferences.setProviderEnabled(id, enabled: $0) }
                            ))
                            .labelsHidden()

                            // Provider Identity
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(id.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(isEnabled ? .primary : .secondary)

                                    if let source = snapshot?.credentialSource {
                                        Text(source)
                                            .font(.system(size: 8))
                                            .foregroundColor(.cyan)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.cyan.opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    if isPrimary {
                                        Text("Primary")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.yellow.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(statusDescription(for: id, snapshot: snapshot, isEnabled: isEnabled))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Set as Primary Action
                            if isEnabled && !isPrimary {
                                Button("Set Primary") {
                                    preferences.preferredPrimaryProviderID = id
                                    manager.setPrimaryProvider(id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            // Refresh Action
                            Button(action: {
                                manager.refresh(providerID: id)
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 9))
                            }
                            .buttonStyle(.plain)
                            .disabled(!isEnabled)

                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .help("Drag to reorder")
                        }

                        // Inline Login & Credential Drawer for OpenCode Go
                        if id == .openCodeGo && isEnabled {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)

                                    SecureField("OpenCode Go API Key / Token", text: $openCodeInputKey)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                        .frame(maxWidth: 240)

                                    Button("Save") {
                                        preferences.setOpenCodeApiKey(openCodeInputKey)
                                        manager.refresh(providerID: .openCodeGo)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(openCodeInputKey.isEmpty)

                                    if !preferences.openCodeApiKey.isEmpty {
                                        Button("Clear") {
                                            openCodeInputKey = ""
                                            preferences.setOpenCodeApiKey("")
                                            manager.refresh(providerID: .openCodeGo)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                HStack(spacing: 12) {
                                    Button(action: {
                                        openTerminalLogin()
                                    }) {
                                        Label("Run 'opencode auth login' in Terminal", systemImage: "terminal")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.link)
                                }
                            }
                            .padding(.leading, 32)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        }

                        if id == .grok && isEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Button(action: {
                                    manager.signInGrok()
                                }) {
                                    Label("Sign in with `grok login --oauth`", systemImage: "terminal")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.link)
                            }
                            .padding(.leading, 32)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveProviders)
            }
            .listStyle(.inset)
        }
        .onAppear {
            openCodeInputKey = preferences.openCodeApiKey
        }
    }

    private func statusDescription(for id: AIProviderID, snapshot: AIProviderSnapshot?, isEnabled: Bool) -> String {
        guard isEnabled else { return "Disabled by user" }
        guard let snapshot = snapshot else { return "Checking…" }
        if snapshot.status == .ready {
            return "Ready • \(snapshot.compactMetric.value)"
        } else {
            return snapshot.status.shortDescription
        }
    }

    private func openTerminalLogin() {
        let script = "tell application \"Terminal\" to do script \"opencode auth login\" activate"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func moveProviders(from source: IndexSet, to destination: Int) {
        var ids = manager.providerIDs
        ids.move(fromOffsets: source, toOffset: destination)
        preferences.setProviderOrder(ids)
        manager.applyProviderOrder(ids)
    }
}
