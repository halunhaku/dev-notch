import Foundation

/// Defines the three primary display states of Dev Notch.
enum NotchState: String, CaseIterable, Equatable, Sendable {
    /// Flush with the physical MacBook notch or screen top.
    case compact
    /// Slightly expanded on mouse hover with interactive preview.
    case hovered
    /// Fully expanded on click showing developer tools & AI status.
    case expanded
}
