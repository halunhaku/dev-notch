import SwiftUI

struct PrimaryProviderCard: View {
    let snapshot: AIProviderSnapshot
    var onRefresh: () -> Void
    var onSignIn: (() -> Void)? = nil
    var onToggleLiveActivity: (() -> Void)? = nil
    @Environment(\.locale) private var locale

    private var remaining: Double? { snapshot.primaryRemainingPercent }
    private var usageWindow: AIUsageWindow? {
        snapshot.metrics.compactMap { metric -> AIUsageWindow? in
            if case .usageWindow(let window) = metric { return window }
            return nil
        }.first
    }

    var body: some View {
        DNCard(accentBorder: DNTheme.Color.accent.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 6) {
                header
                metricBlock
                statusBody
                footer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DNTheme.Space.chip) {
            DNProviderGlyph(id: snapshot.id, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    DNBadge(text: "Primary")
                    Spacer(minLength: 0)
                    DNStatusPill(status: snapshot.status)
                }
                HStack(spacing: 6) {
                    Text(snapshot.displayName)
                        .font(DNTheme.Typeface.providerName)
                        .foregroundStyle(DNTheme.Color.textPrimary)
                        .lineLimit(1)
                    Text(snapshot.account?.displayPlanName ?? "Standard")
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    if let source = snapshot.credentialSource {
                        Text(source)
                            .font(DNTheme.Typeface.badge)
                            .foregroundStyle(DNTheme.Color.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(DNTheme.Color.accentSoft)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var metricBlock: some View {
        if snapshot.status == .ready {
            HStack(alignment: .firstTextBaseline) {
                DNMetricText(text: remaining.map { "\(Int(round($0)))%" } ?? snapshot.compactMetric.value, size: 24)
                Spacer(minLength: 8)
                if let usageWindow {
                    Text(usageWindow.resetTimeRemaining(locale: locale) ?? "")
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                        .lineLimit(1)
                }
            }

            if let remaining, let usageWindow {
                DNProgressBar(
                    progress: remaining / 100.0,
                    tint: DNTheme.quotaTint(remainingPercent: remaining, brand: DNTheme.Color.success)
                )
                HStack {
                    Text(LocalizedStringKey(usageWindow.label))
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    Spacer()
                    Text("\(Int(round(remaining)))% remaining")
                        .font(DNTheme.Typeface.caption)
                        .monospacedDigit()
                        .foregroundStyle(DNTheme.Color.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBody: some View {
        switch snapshot.status {
        case .ready:
            extraMetrics
            liveActivityRow
        case .checking:
            HStack(spacing: DNTheme.Space.chip) {
                ProgressView().controlSize(.small)
                Text("Checking provider connectivity…")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textSecondary)
            }
        case .notAuthenticated:
            HStack(alignment: .center, spacing: 8) {
                Text(LocalizedStringKey(authHelpHint))
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if let onSignIn {
                    Button("Sign in", action: onSignIn)
                        .buttonStyle(.plain)
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DNTheme.Color.cardHover)
                        .clipShape(Capsule())
                }
            }
        case .notInstalled:
            Text("CLI/App not found")
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.critical)
        case .unavailable(let reason), .error(let reason):
            Text(reason)
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.textTertiary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var extraMetrics: some View {
        let extras = snapshot.metrics.filter {
            if case .usageWindow = $0 { return false }
            return true
        }
        if !extras.isEmpty {
            VStack(spacing: 6) {
                ForEach(extras) { metric in
                    switch metric {
                    case .usageWindow:
                        EmptyView()
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
        }
    }

    @ViewBuilder
    private var liveActivityRow: some View {
        if snapshot.id == .claude || snapshot.id == .antigravity, let toggle = onToggleLiveActivity {
            HStack {
                Circle()
                    .fill(snapshot.isLiveActivityEnabled ? DNTheme.Color.success : DNTheme.Color.textMuted)
                    .frame(width: 5, height: 5)
                Text(snapshot.isLiveActivityEnabled ? "Live Activity Active" : "Live Activity Off")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textSecondary)
                Spacer()
                Button(snapshot.isLiveActivityEnabled ? "Disable" : "Enable", action: toggle)
                    .buttonStyle(.plain)
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.accent)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: DNTheme.Space.chip) {
            if let usageWindow, let reset = usageWindow.formattedResetDate(locale: locale) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                    .foregroundStyle(DNTheme.Color.textTertiary)
                Text(verbatim: reset)
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
                    .lineLimit(1)
            }
            if let lastUpdated = snapshot.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: onRefresh) {
                HStack(spacing: 3) {
                    Text("Refresh")
                    Image(systemName: "arrow.right")
                }
                .font(DNTheme.Typeface.caption)
                .foregroundStyle(DNTheme.Color.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DNTheme.Color.cardHover)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var authHelpHint: String {
        switch snapshot.id {
        case .codex: return "Click Sign in to run `codex login`"
        case .openCodeGo: return "Configure OpenCode Go in ~/.local/share/opencode/auth.json"
        case .deepseek: return "Set DEEPSEEK_API_KEY or configure in OpenCode"
        case .claude: return "Click Sign in to run `claude auth login`"
        case .antigravity: return "Sign in using Google Account in Antigravity CLI or Desktop"
        case .grok: return "Click Sign in to run `grok login --oauth`"
        }
    }
}
