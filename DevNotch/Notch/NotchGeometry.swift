import AppKit

/// Pure geometry calculator for physical notch metrics, visual sizes, and window frames.
struct NotchGeometry {
    /// Transparent horizontal padding around the visual notch for soft shadows and smooth anti-aliasing.
    static let horizontalPadding: CGFloat = 16
    /// Transparent bottom padding for drop shadow rendering without clipping.
    static let bottomPadding: CGFloat = 16

    /// Determines whether the given NSScreen has a physical camera notch.
    static func hasNotch(on screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 &&
                   screen.auxiliaryTopLeftArea != nil &&
                   screen.auxiliaryTopRightArea != nil
        }
        return false
    }

    /// Calculates the physical notch bounding rect in screen coordinates (origin bottom-left).
    static func notchBounds(on screen: NSScreen) -> CGRect {
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           left.width > 0, right.width > 0 {
            let notchX = left.maxX
            let notchWidth = max(0, right.minX - left.maxX)
            let notchHeight = screen.safeAreaInsets.top
            let notchY = screen.frame.maxY - notchHeight
            return CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
        }

        // Fallback for non-notch displays (virtual island centered at top of screen)
        let defaultWidth: CGFloat = 180
        let defaultHeight: CGFloat = 32
        let notchX = screen.frame.midX - defaultWidth / 2
        let notchY = screen.frame.maxY - defaultHeight
        return CGRect(x: notchX, y: notchY, width: defaultWidth, height: defaultHeight)
    }

    /// Returns the target visual size of the black notch island for a given state.
    static func visualSize(for state: NotchState, on screen: NSScreen) -> CGSize {
        let base = notchBounds(on: screen)
        switch state {
        case .compact:
            return CGSize(width: max(180, base.width), height: max(32, base.height))
        case .hovered:
            return CGSize(width: max(280, base.width + 90), height: max(56, base.height + 24))
        case .expanded:
            return CGSize(width: 420, height: 320)
        }
    }

    /// Returns the corner radius for the bottom corners of the notch shape.
    static func cornerRadius(for state: NotchState) -> CGFloat {
        switch state {
        case .compact:
            return 12
        case .hovered:
            return 18
        case .expanded:
            return 22
        }
    }

    /// Calculates the full NSWindow frame in screen coordinates.
    /// The window is anchored at the top of the screen (`screen.frame.maxY`).
    static func windowFrame(for state: NotchState, on screen: NSScreen) -> CGRect {
        let size = visualSize(for: state, on: screen)
        let windowWidth = size.width + horizontalPadding * 2
        let windowHeight = size.height + bottomPadding
        let x = screen.frame.midX - windowWidth / 2
        let y = screen.frame.maxY - windowHeight
        return CGRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }

    /// Returns the rect of the visible black notch in window-local coordinates.
    /// In window coordinates, (0, 0) is the bottom-left corner of the window.
    static func visualRectInWindow(for state: NotchState, on screen: NSScreen) -> CGRect {
        let size = visualSize(for: state, on: screen)
        let x = horizontalPadding
        let y = bottomPadding
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
