import SwiftUI

/// Expanded state displaying the multi-provider dashboard in Dev Notch.
struct ExpandedNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var providerManager: AIProviderManager
    var onOpenSettings: (() -> Void)? = nil

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: App Logo, Settings Button & Collapse Button
            HStack {
                // App Logo & Title
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)

                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Dev Notch")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("v\(versionString)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(spacing: 6) {
                    // Settings Button
                    if let openSettings = onOpenSettings {
                        Button(action: openSettings) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings")
                    }

                    // Collapse Button
                    Button(action: {
                        model.collapseToCompact()
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Collapse Notch")
                }
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            // Section: AI Status Center Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)

                Text("AI Status Center")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Text("\(providerManager.providerIDs.count) Providers")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Scrollable Multi-Provider Cards Container
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(providerManager.providerIDs, id: \.self) { id in
                        if let snapshot = providerManager.snapshots[id] {
                            AIProviderCard(
                                snapshot: snapshot,
                                isPrimary: id == providerManager.preferredPrimaryID,
                                onSetPrimary: {
                                    providerManager.setPrimaryProvider(id)
                                },
                                onRefresh: {
                                    providerManager.refresh(providerID: id)
                                },
                                onToggleLiveActivity: (id == .claude || id == .antigravity) ? {
                                    if id == .claude {
                                        providerManager.toggleClaudeLiveActivity()
                                    } else if id == .antigravity {
                                        providerManager.toggleAntigravityLiveActivity()
                                    }
                                } : nil
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 220)

            Spacer(minLength: 0)

            // Bottom Hint
            HStack {
                Spacer()
                Text("Click ★ to set Primary • Tap outside or Esc to collapse")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
