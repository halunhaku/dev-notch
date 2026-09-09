import SwiftUI

/// Detailed status and metrics card for an individual AI Provider snapshot.
struct AIProviderCard: View {
    let snapshot: AIProviderSnapshot
    let isPrimary: Bool
    var onSetPrimary: () -> Void
    var onRefresh: () -> Void
    var onToggleLiveActivity: (() -> Void)? = nil
    var onSignIn: (() -> Void)? = nil

    private var statusBadgeColor: Color {
        switch snapshot.status {
        case .ready: return Color.green
        case .checking: return Color.cyan
        case .notAuthenticated: return Color.orange
        case .notInstalled, .unavailable, .error: return Color.red
        }
    }

    private var planTitle: String {
        snapshot.account?.displayPlanName ?? "Standard"
    }

    private var providerIconName: String {
        switch snapshot.id {
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .openCodeGo: return "terminal.fill"
        case .deepseek: return "brain"
        case .claude: return "sparkles"
        case .antigravity: return "atom"
        case .grok: return "bolt.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Provider Identity, Credential Source, Primary Toggle, Status Pill
            HStack(spacing: 6) {
                // Provider Glyph
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 22, height: 22)

                    Image(systemName: providerIconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }

                Text(snapshot.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                // Plan Badge
                Text(planTitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                // Credential Source Badge (e.g. "via OpenCode")
                if let source = snapshot.credentialSource {
                    Text(source)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.cyan.opacity(0.8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.cyan.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Primary Star / Pin Button
                Button(action: onSetPrimary) {
                    HStack(spacing: 2) {
                        Image(systemName: isPrimary ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundColor(isPrimary ? .yellow : .white.opacity(0.35))

                        if isPrimary {
                            Text("Primary")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.yellow.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isPrimary ? Color.yellow.opacity(0.12) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(isPrimary ? "Current primary notch provider" : "Click to set as primary provider")

                Spacer()

                // Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusBadgeColor)
                        .frame(width: 5, height: 5)

                    Text(snapshot.status.shortDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusBadgeColor.opacity(0.9))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusBadgeColor.opacity(0.15))
                .clipShape(Capsule())
            }

            // Body: Generic Provider Metrics or State Details
            switch snapshot.status {
            case .ready:
                if !snapshot.metrics.isEmpty {
                    VStack(spacing: 7) {
                        ForEach(snapshot.metrics) { metric in
                            switch metric {
                            case .usageWindow(let window):
                                AIUsageBar(window: window)
                            case .balance(let balance):
                                AIBalanceView(balance: balance)
                            case .credits(let credits):
                                AICreditsView(credits: credits)
                            case .context(let context):
                                AIContextView(context: context)
                            case .sessionCost(let cost):
                                AISessionCostView(cost: cost)
                            }
                        }
                    }
                } else if snapshot.id == .claude {
                    Text("Subscription usage not exposed externally")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 1)
                } else if snapshot.id == .antigravity {
                    Text("Usage quota not exposed through machine-readable interface")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 1)
                } else if snapshot.id == .grok {
                    Text("Signed in via Grok CLI")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 1)
                } else {
                    Text("No metric data available")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 2)
                }

                // Live Activity Control Row (Claude & Antigravity)
                if snapshot.id == .claude || snapshot.id == .antigravity {
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(snapshot.isLiveActivityEnabled ? Color.green : Color.white.opacity(0.3))
                                .frame(width: 5, height: 5)

                            Text(snapshot.isLiveActivityEnabled ? "Live Activity Active" : "Live Activity Off")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        if let toggleAction = onToggleLiveActivity {
                            Button(action: toggleAction) {
                                Text(snapshot.isLiveActivityEnabled ? "Disable" : "Enable")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }

            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.55)
                    Text("Checking provider connectivity…")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.vertical, 4)

            case .notAuthenticated:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sign in required")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)

                    Text(LocalizedStringKey(authHelpHint(for: snapshot.id)))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))

                    if let onSignIn {
                        Button(action: onSignIn) {
                            Text("Sign in")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 3)

            case .notInstalled:
                VStack(alignment: .leading, spacing: 2) {
                    Text("CLI/App not found")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red.opacity(0.9))

                    Text("Ensure executable is installed in PATH")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.vertical, 3)

            case .unavailable(let reason), .error(let reason):
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unavailable")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red.opacity(0.9))

                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
                .padding(.vertical, 3)
            }

            // Footer: Timestamp & Refresh
            HStack {
                if let lastUpdated = snapshot.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                Button(action: onRefresh) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8))
                        Text("Refresh")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(11)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func authHelpHint(for id: AIProviderID) -> String {
        switch id {
        case .codex: return "Click Sign in to run `codex login`"
        case .openCodeGo: return "Configure OpenCode Go in ~/.local/share/opencode/auth.json"
        case .deepseek: return "Set DEEPSEEK_API_KEY or configure in OpenCode"
        case .claude: return "Click Sign in to run `claude auth login`"
        case .antigravity: return "Sign in using Google Account in Antigravity CLI or Desktop"
        case .grok: return "Click Sign in to run `grok login --oauth`"
        }
    }
}
