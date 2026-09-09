import AppKit
import SwiftUI

/// Shared island design tokens. Views must not invent spacing, color, or type.
enum DNTheme {
    enum Space {
        static let page: CGFloat = 14
        static let section: CGFloat = 8
        static let card: CGFloat = 12
        static let cardCompact: CGFloat = 10
        static let control: CGFloat = 8
        static let chip: CGFloat = 6
        static let nav: CGFloat = 3
        static let hairline: CGFloat = 0.5
        static let progress: CGFloat = 4
        static let progressCompact: CGFloat = 3
    }

    enum Radius {
        static let card: CGFloat = 16
        static let inner: CGFloat = 12
        static let chip: CGFloat = 8
        static let icon: CGFloat = 8
        static let nav: CGFloat = 12
        static let pill: CGFloat = 20
    }

    enum Color {
        static let accent = SwiftUI.Color(red: 0.43, green: 0.40, blue: 0.98)
        static let accentSoft = SwiftUI.Color(red: 0.43, green: 0.40, blue: 0.98).opacity(0.22)
        static let accentGlow = SwiftUI.Color(red: 0.38, green: 0.32, blue: 1.0).opacity(0.55)
        static let success = SwiftUI.Color(red: 0.27, green: 0.82, blue: 0.48)
        static let warning = SwiftUI.Color.orange
        static let critical = SwiftUI.Color(red: 0.95, green: 0.36, blue: 0.40)

        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.62)
        static let textTertiary = SwiftUI.Color.white.opacity(0.38)
        static let textMuted = SwiftUI.Color.white.opacity(0.28)

        static let cardFill = SwiftUI.Color.white.opacity(0.055)
        static let cardHover = SwiftUI.Color.white.opacity(0.09)
        static let track = SwiftUI.Color.white.opacity(0.10)
        static let hairline = SwiftUI.Color.white.opacity(0.08)
        static let island = SwiftUI.Color.black
        static let islandStroke = SwiftUI.Color.white.opacity(0.14)
        static let navIdle = SwiftUI.Color.white.opacity(0.055)
    }

    enum Typeface {
        static let pageTitle = Font.system(size: 13, weight: .semibold)
        static let sectionTitle = Font.system(size: 11, weight: .semibold)
        static let providerName = Font.system(size: 15, weight: .semibold)
        static let metricLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let metricMedium = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 11, weight: .regular)
        static let caption = Font.system(size: 9, weight: .medium)
        static let compact = Font.system(size: 10, weight: .semibold)
        static let badge = Font.system(size: 8, weight: .semibold)
    }

    enum Motion {
        static let notchDuration: TimeInterval = 0.22
        static let notchDurationReduced: TimeInterval = 0.12
        static let tabDuration: TimeInterval = 0.16
        static var windowTiming: CAMediaTimingFunction {
            CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        }

        static var reduceMotion: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        static var notchAnimation: Animation {
            reduceMotion
                ? .easeOut(duration: notchDurationReduced)
                : .spring(response: 0.22, dampingFraction: 0.94)
        }

        static var tabAnimation: Animation {
            .easeOut(duration: reduceMotion ? 0.10 : tabDuration)
        }

        static var progressAnimation: Animation {
            .easeOut(duration: reduceMotion ? 0.10 : 0.28)
        }

        static var windowDuration: TimeInterval {
            reduceMotion ? notchDurationReduced : notchDuration
        }
    }

    static func providerSymbol(for id: AIProviderID) -> String {
        switch id {
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .openCodeGo: return "cube.fill"
        case .deepseek: return "brain"
        case .claude: return "sparkles"
        case .antigravity: return "atom"
        case .grok: return "bolt.fill"
        }
    }

    static func providerColor(for id: AIProviderID) -> SwiftUI.Color {
        switch id {
        case .grok: return Color.accent
        case .codex: return SwiftUI.Color(red: 0.47, green: 0.56, blue: 0.98)
        case .claude: return SwiftUI.Color(red: 0.86, green: 0.50, blue: 0.28)
        case .antigravity: return SwiftUI.Color(red: 0.55, green: 0.46, blue: 0.96)
        case .openCodeGo: return SwiftUI.Color(red: 0.27, green: 0.80, blue: 0.54)
        case .deepseek: return SwiftUI.Color(red: 0.32, green: 0.56, blue: 0.96)
        }
    }

    static func quotaTint(remainingPercent: Double, brand: SwiftUI.Color) -> SwiftUI.Color {
        if remainingPercent >= 40 { return Color.success }
        if remainingPercent >= 15 { return Color.warning }
        return Color.critical
    }

    static func statusColor(for status: AIProviderStatus) -> SwiftUI.Color {
        switch status {
        case .ready: return Color.success
        case .checking: return Color.accent
        case .notAuthenticated: return Color.warning
        case .notInstalled, .unavailable, .error: return Color.critical
        }
    }
}
