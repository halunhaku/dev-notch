import SwiftUI

struct SystemInsightsView: View {
    @ObservedObject var store: SystemMetricsStore
    var isVisible: Bool = true
    @Environment(\.locale) private var locale


    var body: some View {
        VStack(spacing: DNTheme.Space.section) {
            HStack(spacing: DNTheme.Space.section) {
                cpuCard
                memoryCard
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: DNTheme.Space.section) {
                networkCard
                powerCard
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            tint: DNTheme.Color.success,
            progress: store.snapshot.cpuUsage,
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
            progress: store.snapshot.memoryUsage,
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
            tint: DNTheme.Color.success,
            progress: nil,
            primaryHistory: store.history.download,
            secondaryHistory: store.history.upload,
            fixedMaximum: nil
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Network throughput")
        .accessibilityValue("Download \(Self.rate(store.snapshot.downloadBytesPerSecond)), upload \(Self.rate(store.snapshot.uploadBytesPerSecond))")
    }

    private var powerCard: some View {
        DNCard(padding: DNTheme.Space.cardCompact, fillsHeight: true) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Battery", systemImage: powerIcon)
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                    Spacer()
                    Text(powerDetail)
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textTertiary)
                        .lineLimit(1)
                }

                DNMetricText(text: powerValue, size: 22)

                if let battery = store.snapshot.battery {
                    DNProgressBar(
                        progress: min(1, max(0, battery.level)),
                        tint: battery.level < 0.2 ? DNTheme.Color.critical : DNTheme.Color.success,
                        height: DNTheme.Space.progressCompact
                    )
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    Text("Temperature")
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(DNTheme.Color.textMuted)
                    Spacer()
                    Text(LocalizedStringKey(store.snapshot.thermalLevel.label))
                        .font(DNTheme.Typeface.caption)
                        .foregroundStyle(thermalTint)
                }

                HStack(spacing: 4) {
                    ForEach(SystemThermalLevel.allDisplayLevels, id: \.rawValue) { level in
                        Capsule()
                            .fill(level == store.snapshot.thermalLevel ? thermalTint : DNTheme.Color.track)
                            .frame(height: 4)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power and thermal state")
        .accessibilityValue("\(powerValue), thermal \(store.snapshot.thermalLevel.label)")
    }

    private var memoryTint: Color {
        switch store.snapshot.memoryPressure {
        case .normal: return DNTheme.Color.success
        case .warning: return DNTheme.Color.warning
        case .critical: return DNTheme.Color.critical
        }
    }

    private var thermalTint: Color {
        switch store.snapshot.thermalLevel {
        case .nominal: return DNTheme.Color.success
        case .fair: return Color.yellow
        case .serious: return DNTheme.Color.warning
        case .critical: return DNTheme.Color.critical
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
    let progress: Double?
    let primaryHistory: MetricHistory
    let secondaryHistory: MetricHistory?
    let fixedMaximum: Double?

    var body: some View {
        DNCard(padding: DNTheme.Space.cardCompact, fillsHeight: true) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)

                DNMetricText(text: value, size: 22)

                Text(detail)
                    .font(DNTheme.Typeface.caption)
                    .foregroundStyle(DNTheme.Color.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let progress {
                    DNProgressBar(
                        progress: min(1, max(0, progress)),
                        tint: tint,
                        height: DNTheme.Space.progressCompact
                    )
                }

                Spacer(minLength: 4)

                ZStack {
                    SystemSparklineShape(history: primaryHistory, fixedMaximum: fixedMaximum)
                        .stroke(tint.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    if let secondaryHistory {
                        SystemSparklineShape(history: secondaryHistory, fixedMaximum: fixedMaximum)
                            .stroke(DNTheme.Color.textSecondary.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 16)
            }
        }
    }
}

private struct SystemSparklineShape: Shape {
    let history: MetricHistory
    let fixedMaximum: Double?

    func path(in rect: CGRect) -> Path {
        guard history.count > 1 else { return Path() }
        let maxValue = max(fixedMaximum ?? history.maximum, 0.001)
        var path = Path()
        for index in 0..<history.count {
            let x = rect.width * CGFloat(index) / CGFloat(history.count - 1)
            let y = rect.height - (rect.height * CGFloat(min(1, max(0, history[index] / maxValue))))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private extension SystemThermalLevel {
    static let allDisplayLevels: [SystemThermalLevel] = [.nominal, .fair, .serious, .critical]
}
