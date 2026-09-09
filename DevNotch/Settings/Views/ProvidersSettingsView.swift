import SwiftUI

struct ProvidersSettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var manager: AIProviderManager
    @Environment(\.locale) private var locale
    @State private var detailID: AIProviderID?

    var body: some View {
        VStack(alignment: .leading, spacing: DNTheme.Space.section) {
            Text("Configure which AI providers are active and select your preferred primary provider. Drag rows to reorder; the expanded AI dashboard uses the same order.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, DNTheme.Space.page)
                .padding(.top, 10)

            List {
                ForEach(manager.providerIDs, id: \.self) { id in
                    providerRow(id)
                }
                .onMove(perform: moveProviders)
            }
            .listStyle(.inset)
        }
        .sheet(item: Binding(
            get: { detailID.map { IdentifiedProvider(id: $0) } },
            set: { detailID = $0?.id }
        )) { item in
            ProviderDetailSheet(id: item.id, preferences: preferences, manager: manager)
        }
    }

    private func providerRow(_ id: AIProviderID) -> some View {
        let isEnabled = preferences.isProviderEnabled(id)
        let isPrimary = preferences.preferredPrimaryProviderID == id
        let snapshot = manager.snapshots[id]

        return HStack(spacing: DNTheme.Space.control) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .help("Drag to reorder")

            Image(systemName: DNTheme.providerSymbol(for: id))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DNTheme.providerColor(for: id))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(id.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                    if let source = snapshot?.credentialSource {
                        Text(source)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if isPrimary {
                        Text("Primary")
                            .font(DNTheme.Typeface.badge)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(statusDescription(for: id, snapshot: snapshot, isEnabled: isEnabled))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEnabled, let snapshot {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DNTheme.statusColor(for: snapshot.status))
                        .frame(width: 6, height: 6)
                    Text(LocalizedStringKey(snapshot.status.shortDescription))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DNTheme.statusColor(for: snapshot.status))
                }
            }

            Toggle("", isOn: Binding(
                get: { preferences.isProviderEnabled(id) },
                set: { preferences.setProviderEnabled(id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Button("Settings") {
                detailID = id
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                if isEnabled && !isPrimary {
                    Button("Set as Primary") {
                        preferences.preferredPrimaryProviderID = id
                        manager.setPrimaryProvider(id)
                    }
                }
                Button("Refresh") {
                    manager.refresh(providerID: id)
                }
                .disabled(!isEnabled)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22)
        }
        .padding(.vertical, 4)
    }

    private func statusDescription(for id: AIProviderID, snapshot: AIProviderSnapshot?, isEnabled: Bool) -> String {
        guard isEnabled else { return L10n.key("Disabled by user", locale: locale) }
        guard let snapshot else { return L10n.key("Checking…", locale: locale) }
        if snapshot.status == .ready {
            return "\(L10n.key("Ready", locale: locale)) • \(snapshot.compactMetric.value)"
        }
        return L10n.key(snapshot.status.shortDescription, locale: locale)
    }

    private func moveProviders(from source: IndexSet, to destination: Int) {
        var ids = manager.providerIDs
        ids.move(fromOffsets: source, toOffset: destination)
        preferences.setProviderOrder(ids)
        manager.applyProviderOrder(ids)
    }
}

private struct IdentifiedProvider: Identifiable {
    let id: AIProviderID
}
