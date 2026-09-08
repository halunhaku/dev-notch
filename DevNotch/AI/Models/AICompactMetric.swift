import SwiftUI

/// Visual severity indicator for the compact notch metric.
enum AICompactMetricSeverity: Equatable, Sendable {
    case normal
    case warning
    case critical
    case inactive

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .inactive: return .cyan
        }
    }
}

/// Generic compact display value for Compact and Hovered notch states.
/// Completely decouples UI from specific provider types (Codex, DeepSeek, OpenCode Go, etc.).
struct AICompactMetric: Equatable, Sendable {
    /// Provider display name or badge (e.g. "Codex", "DeepSeek", "OpenCode Go").
    let label: String
    /// Primary concise value (e.g. "84%", "¥0.73", "Ready", "Offline").
    let value: String
    /// Optional secondary hint (e.g. "5h", nil).
    let secondaryValue: String?
    /// Visual severity driving status dot and value color.
    let severity: AICompactMetricSeverity

    init(
        label: String,
        value: String,
        secondaryValue: String? = nil,
        severity: AICompactMetricSeverity = .normal
    ) {
        self.label = label
        self.value = value
        self.secondaryValue = secondaryValue
        self.severity = severity
    }
}
