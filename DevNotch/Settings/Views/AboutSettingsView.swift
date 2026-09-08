import SwiftUI

struct AboutSettingsView: View {
    private var versionString: String {
        BundleVersion.marketingVersion(infoDictionary: Bundle.main.infoDictionary ?? [:]) ?? "Unknown"
    }

    private var buildString: String {
        BundleVersion.buildNumber(infoDictionary: Bundle.main.infoDictionary ?? [:]) ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            // App Icon Graphic
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.85), Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // Title & Version
            VStack(spacing: 4) {
                Text("Dev Notch")
                    .font(.system(size: 18, weight: .bold))

                Text("Version \(versionString) (\(buildString))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text("Native AI developer activity & usage dynamic island for macOS.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Built 100% with Swift & SwiftUI • macOS 14.0+")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("Local-first privacy architecture • Zero remote telemetry")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
