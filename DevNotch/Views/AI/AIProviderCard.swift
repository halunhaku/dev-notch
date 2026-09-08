import SwiftUI

/// Detailed status and usage card for an active AI Provider in the expanded notch.
struct AIProviderCard: View {
    @ObservedObject var manager: AIProviderManager

    private var statusBadgeColor: Color {
        switch manager.status {
        case .ready: return Color.green
        case .checking: return Color.cyan
        case .notAuthenticated: return Color.orange
        case .notInstalled, .unavailable, .error: return Color.red
        }
    }

    private var planTitle: String {
        manager.account?.displayPlanName ?? "Standard"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Provider Identity & Status Badge
            HStack(spacing: 8) {
                // Provider Glyph
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 22, height: 22)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }

                Text(manager.activeProviderID.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Text(planTitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                Spacer()

                // Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusBadgeColor)
                        .frame(width: 5, height: 5)

                    Text(manager.statusTitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusBadgeColor.opacity(0.9))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusBadgeColor.opacity(0.15))
                .clipShape(Capsule())
            }

            // Body: Content based on provider status
            switch manager.status {
            case .ready:
                if let usage = manager.usage {
                    VStack(spacing: 10) {
                        if let primary = usage.primary {
                            AIUsageBar(window: primary)
                        }

                        if let secondary = usage.secondary {
                            AIUsageBar(window: secondary)
                        }
                    }
                } else {
                    Text("Fetching quota details…")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }

            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Connecting to Codex app-server…")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)

            case .notAuthenticated:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authentication Required")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)

                    Text("Please log in to Codex via terminal: codex login")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.vertical, 4)

            case .notInstalled:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Codex CLI Not Found")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red.opacity(0.9))

                    Text("Ensure `codex` is installed in PATH or Homebrew")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.vertical, 4)

            case .unavailable(let reason), .error(let reason):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Issue")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red.opacity(0.9))

                    Text(reason)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }

            // Footer: Timestamp & Refresh
            HStack {
                if let lastUpdated = manager.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                Button(action: {
                    manager.refresh()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8))
                            .rotationEffect(.degrees(manager.isRefreshing ? 360 : 0))
                            .animation(manager.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: manager.isRefreshing)

                        Text("Refresh")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .disabled(manager.isRefreshing)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
