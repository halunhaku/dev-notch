import AppKit

/// Data model representing the physical camera notch on the current screen.
struct HardwareNotchModel: Equatable, Sendable {
    /// True if the current screen has a physical hardware camera notch cutout.
    let hasHardwareNotch: Bool
    /// The physical notch bounding box in screen coordinates (origin bottom-left, points).
    let screenNotchRect: CGRect
    /// Width of the physical hardware notch cutout (points).
    let hardwareNotchWidth: CGFloat
    /// Height of the physical hardware notch cutout (points).
    let hardwareNotchHeight: CGFloat
    /// Top inset needed so full-width interactive content is placed below the notch.
    let contentTopInset: CGFloat

    static let fallback = HardwareNotchModel(
        hasHardwareNotch: false,
        screenNotchRect: .zero,
        hardwareNotchWidth: 0,
        hardwareNotchHeight: 0,
        contentTopInset: 0
    )

    /// Calculates the width available for content in the left wing beside the notch.
    func leftWingWidth(totalVisualWidth: CGFloat) -> CGFloat {
        guard hasHardwareNotch else { return totalVisualWidth / 2 }
        return max(0, (totalVisualWidth - hardwareNotchWidth) / 2)
    }

    /// Calculates the width available for content in the right wing beside the notch.
    func rightWingWidth(totalVisualWidth: CGFloat) -> CGFloat {
        guard hasHardwareNotch else { return totalVisualWidth / 2 }
        return max(0, (totalVisualWidth - hardwareNotchWidth) / 2)
    }
}

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

    /// Extracts the dynamic hardware notch model for the given display.
    static func hardwareNotchModel(on screen: NSScreen) -> HardwareNotchModel {
        if #available(macOS 12.0, *),
           hasNotch(on: screen),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           left.width > 0, right.width > 0 {
            let notchX = left.maxX
            let notchWidth = max(0, right.minX - left.maxX)
            let notchHeight = screen.safeAreaInsets.top
            let notchY = screen.frame.maxY - notchHeight
            let rect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
            return HardwareNotchModel(
                hasHardwareNotch: true,
                screenNotchRect: rect,
                hardwareNotchWidth: notchWidth,
                hardwareNotchHeight: notchHeight,
                contentTopInset: notchHeight
            )
        }

        return .fallback
    }

    /// Calculates the physical notch bounding rect in screen coordinates (origin bottom-left).
    static func notchBounds(on screen: NSScreen) -> CGRect {
        let model = hardwareNotchModel(on: screen)
        if model.hasHardwareNotch {
            return model.screenNotchRect
        }

        // Fallback for non-notch displays (virtual island centered at top of screen)
        let defaultWidth: CGFloat = 180
        let defaultHeight: CGFloat = 32
        let notchX = screen.frame.midX - defaultWidth / 2
        let notchY = screen.frame.maxY - defaultHeight
        return CGRect(x: notchX, y: notchY, width: defaultWidth, height: defaultHeight)
    }

    static let expandedWidth: CGFloat = 720
    /// Stable dashboard canvas height. Tab changes must never resize the island.
    static let expandedHeight: CGFloat = 460

    /// Returns the target visual size of the black notch island for a given state.
    static func visualSize(
        for state: NotchState,
        on screen: NSScreen
    ) -> CGSize {
        let model = hardwareNotchModel(on: screen)
        if model.hasHardwareNotch {
            switch state {
            case .compact:
                return CGSize(
                    width: model.hardwareNotchWidth,
                    height: max(32, model.hardwareNotchHeight)
                )
            case .hovered:
                return CGSize(
                    width: max(480, model.hardwareNotchWidth + 260),
                    height: max(32, model.hardwareNotchHeight)
                )
            case .expanded:
                return CGSize(
                    width: max(expandedWidth, model.hardwareNotchWidth + 240),
                    height: expandedHeight + model.contentTopInset
                )
            }
        } else {
            switch state {
            case .compact:
                return CGSize(width: 400, height: 32)
            case .hovered:
                return CGSize(width: 400, height: 32)
            case .expanded:
                return CGSize(width: expandedWidth, height: expandedHeight)
            }
        }
    }

    static func cornerRadius(for state: NotchState) -> CGFloat {
        switch state {
        case .compact: return 12
        case .hovered: return 18
        case .expanded: return 22
        }
    }

    /// Window is top-anchored (`screen.frame.maxY`). Height changes move the bottom edge only.
    static func windowFrame(
        for state: NotchState,
        on screen: NSScreen
    ) -> CGRect {
        let windowWidth: CGFloat
        let windowHeight: CGFloat

        switch state {
        case .compact, .hovered:
            let hoveredSize = visualSize(for: .hovered, on: screen)
            windowWidth = hoveredSize.width + horizontalPadding * 2
            let visualHeight = visualSize(for: state, on: screen).height
            windowHeight = visualHeight + bottomPadding
        case .expanded:
            let expandedSize = visualSize(for: .expanded, on: screen)
            windowWidth = expandedSize.width + horizontalPadding * 2
            windowHeight = expandedSize.height + bottomPadding
        }

        let x = screen.frame.midX - windowWidth / 2
        let y = screen.frame.maxY - windowHeight
        return CGRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }

    static func visualRectInWindow(
        for state: NotchState,
        on screen: NSScreen
    ) -> CGRect {
        let windowRect = windowFrame(for: state, on: screen)
        let size = visualSize(for: state, on: screen)
        let x = (windowRect.width - size.width) / 2
        let y = bottomPadding
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    static func acceptsMouse(
        atWindowPoint point: CGPoint,
        state: NotchState,
        on screen: NSScreen
    ) -> Bool {
        visualRectInWindow(for: state, on: screen).contains(point)
    }

}
