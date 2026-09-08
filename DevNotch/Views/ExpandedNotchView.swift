import SwiftUI

/// Expanded state displaying the multi-provider dashboard in Dev Notch.
struct ExpandedNotchView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var providerManager: AIProviderManager
    var onOpenSettings: (() -> Void)? = nil

    private var versionString: String {
        BundleVersion.marketingVersion(infoDictionary: Bundle.main.infoDictionary ?? [:]) ?? "Unknown"
    }

    private var notchModel: HardwareNotchModel {
        screenManager.notchModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if notchModel.hasHardwareNotch {
                let screen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
                let totalWidth = NotchGeometry.visualSize(for: .expanded, on: screen).width
                let wingWidth = notchModel.leftWingWidth(totalVisualWidth: totalWidth)

                // Top Row: Wings on Left and Right of the physical camera notch
                HStack(spacing: 0) {
                    // Left Wing: App Logo, Title & Version
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 20, height: 20)

                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Dev Notch")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)

                        Text("v\(versionString)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .frame(width: wingWidth, alignment: .leading)
                    .padding(.leading, 12)

                    // Center: Physical Hardware Notch Exclusion Zone
                    Color.clear
                        .frame(width: notchModel.hardwareNotchWidth, height: notchModel.hardwareNotchHeight)

                    // Right Wing: Settings Button & Collapse Button
                    HStack(spacing: 6) {
                        Button(action: {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                            openSettings()
                            onOpenSettings?()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings")

                        Button(action: {
                            model.collapseToCompact()
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Collapse Notch")
                    }
                    .frame(width: wingWidth, alignment: .trailing)
                    .padding(.trailing, 12)
                }
                .frame(height: notchModel.hardwareNotchHeight)
            } else {
                // Virtual Island: Unconstrained Top Row
                HStack {
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
                        Button(action: {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                            openSettings()
                            onOpenSettings?()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings")

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
                .padding(.top, 4)
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

                Text("\(providerManager.enabledProviderIDs.count) Active")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Scrollable Multi-Provider Cards Container
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(providerManager.enabledProviderIDs, id: \.self) { id in
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
