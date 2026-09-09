import SwiftUI

struct SystemInsightsView: View {
    @ObservedObject var store: SystemMetricsStore
    var isVisible: Bool = true
    @Environment(\.locale) private var locale

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)

                Text("System Insights")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Circle()
                    .fill(store.isSampling ? Color.green : Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)

                Text(store.isSampling ? "Live" : "Paused")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            LazyVGrid(columns: columns, spacing: 8) {
                cpuCard
                memoryCard
                networkCard
                powerCard
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "leaf")
                    .font(.system(size: 8, weight: .semibold))
                Text("1 Hz only while visible")
                Spacer()
                if let interfaceName = store.snapshot.networkInterfaceName {
                    Text(interfaceName)
                        .monospaced()
                }
            }
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isVisible, initial: true) { _, visible in
            store.setActive(visible)
        }
        .onDisappear { store.setActive(false) }
    }

    private var cpuCard: some View {
        SystemMetricCard(
            title: LocalizedStringKey("CPU"),
            value: Self.percent(store.snapshot.cpuUsage),
            detail: store.snapshot.cpuUsage == nil
                ? L10n.key("Calculating delta", locale: locale)
                : L10n.key("Total utilization", locale: locale),
            systemImage: "cpu",
            tint: .cyan,
            primaryHistory: store.history.cpu,
            secondaryHistory: nil,
            fixedMaximum: 1
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CPU utilization")
        .accessibilityValue(Self.percent(store.snapshot.cpuUsage))
    }

    private var memoryCard: some View {
        SystemMetricCard(
            title: LocalizedStringKey("Memory"),
            value: Self.percent(store.snapshot.memoryUsage),
            detail: L10n.format(
                "%@ used · %@",
                locale: locale,
                Self.memory(store.snapshot.memoryUsedBytes),
                L10n.key(store.snapshot.memoryPressure.label, locale: locale)
            ),
            systemImage: "memorychip",
            tint: memoryTint,
            primaryHistory: store.history.memory,
            secondaryHistory: nil,
            fixedMaximum: 1
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Memory utilization")
        .accessibilityValue("\(Self.percent(store.snapshot.memoryUsage)), pressure \(store.snapshot.memoryPressure.label)")
    }

    private var networkCard: some View {
        SystemMetricCard(
            title: LocalizedStringKey("Network"),
            value: "↓ \(Self.rate(store.snapshot.downloadBytesPerSecond))",
            detail: "↑ \(Self.rate(store.snapshot.uploadBytesPerSecond))",
            systemImage: "arrow.up.arrow.down",
            tint: .mint,
            primaryHistory: store.history.download,
            secondaryHistory: store.history.upload,
            fixedMaximum: nil
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Network throughput")
        .accessibilityValue("Download \(Self.rate(store.snapshot.downloadBytesPerSecond)), upload \(Self.rate(store.snapshot.uploadBytesPerSecond))")
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Power & Thermal", systemImage: powerIcon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
                Text(LocalizedStringKey(store.snapshot.thermalLevel.label))
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(thermalTint)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(powerValue)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(powerDetail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                ForEach(SystemThermalLevel.allDisplayLevels, id: \.rawValue) { level in
                    Capsule()
                        .fill(level == store.snapshot.thermalLevel ? thermalTint : Color.white.opacity(0.1))
                        .frame(height: 4)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power and thermal state")
        .accessibilityValue("\(powerValue), thermal \(store.snapshot.thermalLevel.label)")
    }

    private var memoryTint: Color {
        switch store.snapshot.memoryPressure {
        case .normal: .purple
        case .warning: .orange
        case .critical: .red
        }
    }

    private var thermalTint: Color {
        switch store.snapshot.thermalLevel {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }

    private var powerIcon: String {
        guard let battery = store.snapshot.battery else { return "thermometer.medium" }
        return battery.isCharging ? "battery.100.bolt" : "battery.75"
    }

    private var powerValue: String {
        guard let battery = store.snapshot.battery else { return store.snapshot.thermalLevel.label }
        return Self.percent(battery.level)
    }

    private var powerDetail: String {
        guard let battery = store.snapshot.battery else { return L10n.key("Thermal state", locale: locale) }
        if battery.isCharging { return L10n.key("Charging", locale: locale) }
        return battery.isOnACPower ? L10n.key("AC power", locale: locale) : L10n.key("On battery", locale: locale)
    }

    private static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((min(1, max(0, value)) * 100).rounded()))%"
    }

    private static func memory(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    private static func rate(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        if value >= 1_048_576 {
            return String(format: "%.1f MB/s", value / 1_048_576)
        }
        if value >= 1_024 {
            return String(format: "%.0f KB/s", value / 1_024)
        }
        return String(format: "%.0f B/s", value)
    }
}

private struct SystemMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    let primaryHistory: MetricHistory
    let secondaryHistory: MetricHistory?
    let fixedMaximum: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(detail)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            ZStack {
                SystemSparklineShape(history: primaryHistory, fixedMaximum: fixedMaximum)
                    .stroke(tint.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let secondaryHistory {
                    SystemSparklineShape(history: secondaryHistory, fixedMaximum: fixedMaximum)
                        .stroke(Color.blue.opacity(0.62), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 14)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

private struct SystemSparklineShape: Shape {
    let history: MetricHistory
    let fixedMaximum: Double?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard history.count > 1 else { return path }

        let maximum = max(fixedMaximum ?? history.maximum, 0.000_001)
        let xStep = rect.width / CGFloat(history.capacity - 1)
        let leadingEmptySamples = history.capacity - history.count

        for index in 0..<history.count {
            let x = CGFloat(leadingEmptySamples + index) * xStep
            let normalized = min(1, max(0, history[index] / maximum))
            let y = rect.maxY - CGFloat(normalized) * rect.height
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private extension SystemThermalLevel {
    static let allDisplayLevels: [SystemThermalLevel] = [.nominal, .fair, .serious, .critical]
}
