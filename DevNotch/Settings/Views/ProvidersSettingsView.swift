import SwiftUI

struct ProvidersSettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var manager: AIProviderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configure which AI providers are active and select your preferred primary provider.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            List {
                ForEach(manager.providerIDs, id: \.self) { id in
                    let isEnabled = preferences.isProviderEnabled(id)
                    let isPrimary = preferences.preferredPrimaryProviderID == id
                    let snapshot = manager.snapshots[id]

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
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
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
}
