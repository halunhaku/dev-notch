import SwiftUI

/// Expanded state displaying the core dashboard for Dev Notch and live AI Provider status.
struct ExpandedNotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var providerManager: AIProviderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: App Brand & Collapse Button
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

                    Text("v0.2.0")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                Spacer()

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
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            // Section: AI Status Center with real Provider Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("AI Status Center")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Spacer()
                }

                // Live AI Provider Card
                AIProviderCard(manager: providerManager)
            }

            Spacer(minLength: 0)

            // Bottom hint
            HStack {
                Spacer()
                Text("Click outside to collapse")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
