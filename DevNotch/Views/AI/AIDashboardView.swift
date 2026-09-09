import SwiftUI

struct AIDashboardView: View {
    @ObservedObject var manager: AIProviderManager

    private var primaryID: AIProviderID {
        let enabled = manager.enabledProviderIDs
        if enabled.contains(manager.preferredPrimaryID) {
            return manager.preferredPrimaryID
        }
        return enabled.first ?? manager.preferredPrimaryID
    }

    private var secondaryIDs: [AIProviderID] {
        manager.enabledProviderIDs.filter { $0 != primaryID }
    }

    private var secondaryRows: [[AIProviderID]] {
        guard secondaryIDs.count > 3 else { return [secondaryIDs] }
        let splitIndex = (secondaryIDs.count + 1) / 2
        return [
            Array(secondaryIDs.prefix(splitIndex)),
            Array(secondaryIDs.dropFirst(splitIndex))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNTheme.Space.section) {
            if let snapshot = manager.snapshots[primaryID] {
                PrimaryProviderCard(
                    snapshot: snapshot,
                    onRefresh: { manager.refresh(providerID: primaryID) },
                    onSignIn: [.grok, .codex, .claude].contains(primaryID) ? {
                        manager.signIn(providerID: primaryID)
                    } : nil,
                    onToggleLiveActivity: (primaryID == .claude || primaryID == .antigravity) ? {
                        if primaryID == .claude {
                            manager.toggleClaudeLiveActivity()
                        } else {
                            manager.toggleAntigravityLiveActivity()
                        }
                    } : nil
                )
            }

            if !secondaryIDs.isEmpty {
                VStack(spacing: DNTheme.Space.section) {
                    ForEach(Array(secondaryRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: DNTheme.Space.section) {
                            ForEach(row, id: \.self) { id in
                                if let snapshot = manager.snapshots[id] {
                                    SecondaryProviderCard(snapshot: snapshot)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
