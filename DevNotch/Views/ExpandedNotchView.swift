import SwiftUI

/// Expanded state displaying the core dashboard for Dev Notch and AI Status Center.
struct ExpandedNotchView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
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

                    Text("v0.1.0")
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

            // Section: AI Status Center
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("AI Status Center")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    Text("Standby")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Status Card
                VStack(spacing: 6) {
                    HStack {
                        Label("AI Providers", systemImage: "cpu")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("Architecture Ready")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    HStack {
                        Label("Display Mode", systemImage: "laptopcomputer")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("MacBook Notch Connected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
