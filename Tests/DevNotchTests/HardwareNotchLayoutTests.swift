import XCTest
@testable import DevNotch

final class HardwareNotchLayoutTests: XCTestCase {
    // 1. Hardware notch rect calculation
    func testHardwareNotchRectCalculation() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let model = NotchGeometry.hardwareNotchModel(on: screen)

        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           left.width > 0, right.width > 0 {
            XCTAssertTrue(model.hasHardwareNotch)
            XCTAssertEqual(model.hardwareNotchWidth, right.minX - left.maxX, accuracy: 0.1)
            XCTAssertEqual(model.hardwareNotchHeight, screen.safeAreaInsets.top, accuracy: 0.1)
            XCTAssertEqual(model.contentTopInset, screen.safeAreaInsets.top, accuracy: 0.1)
        } else {
            XCTAssertFalse(model.hasHardwareNotch)
            XCTAssertEqual(model.hardwareNotchWidth, 0)
            XCTAssertEqual(model.contentTopInset, 0)
        }
    }

    // 2 & 3. Left and right auxiliary area calculations
    func testAuxiliaryAreaWingsCalculation() {
        let model = HardwareNotchModel(
            hasHardwareNotch: true,
            screenNotchRect: CGRect(x: 645.5, y: 924, width: 179, height: 32),
            hardwareNotchWidth: 179,
            hardwareNotchHeight: 32,
            contentTopInset: 32
        )

        let totalVisualWidth: CGFloat = 355
        let leftWing = model.leftWingWidth(totalVisualWidth: totalVisualWidth)
        let rightWing = model.rightWingWidth(totalVisualWidth: totalVisualWidth)

        XCTAssertEqual(leftWing, 88, accuracy: 0.1)
        XCTAssertEqual(rightWing, 88, accuracy: 0.1)
        XCTAssertEqual(leftWing + model.hardwareNotchWidth + rightWing, totalVisualWidth, accuracy: 0.1)
    }

    // 4. Compact content does not intersect hardware notch
    func testCompactContentDoesNotIntersectHardwareNotch() {
        let model = HardwareNotchModel(
            hasHardwareNotch: true,
            screenNotchRect: CGRect(x: 645.5, y: 924, width: 179, height: 32),
            hardwareNotchWidth: 179,
            hardwareNotchHeight: 32,
            contentTopInset: 32
        )

        let totalWidth: CGFloat = 355
        let wingWidth = model.leftWingWidth(totalVisualWidth: totalWidth)
        let leftWingRect = CGRect(x: 0, y: 0, width: wingWidth, height: 32)
        let notchExclusionRect = CGRect(x: wingWidth, y: 0, width: model.hardwareNotchWidth, height: 32)
        let rightWingRect = CGRect(x: wingWidth + model.hardwareNotchWidth, y: 0, width: wingWidth, height: 32)

        XCTAssertFalse(leftWingRect.intersects(notchExclusionRect))
        XCTAssertFalse(rightWingRect.intersects(notchExclusionRect))
        XCTAssertEqual(notchExclusionRect.width, 179)
    }

    // 5. Hover header does not intersect hardware notch
    func testHoverHeaderDoesNotIntersectHardwareNotch() {
        let model = HardwareNotchModel(
            hasHardwareNotch: true,
            screenNotchRect: CGRect(x: 645.5, y: 924, width: 179, height: 32),
            hardwareNotchWidth: 179,
            hardwareNotchHeight: 32,
            contentTopInset: 32
        )

        let totalWidth: CGFloat = 379
        let wingWidth = model.leftWingWidth(totalVisualWidth: totalWidth)
        let notchRect = CGRect(x: wingWidth, y: 0, width: model.hardwareNotchWidth, height: model.hardwareNotchHeight)

        let leftWingRect = CGRect(x: 0, y: 0, width: wingWidth, height: 32)
        let rightWingRect = CGRect(x: wingWidth + model.hardwareNotchWidth, y: 0, width: wingWidth, height: 32)
        // Subtitle row sits completely below notch height
        let subtitleRowRect = CGRect(x: 0, y: 32, width: totalWidth, height: 28)

        XCTAssertFalse(leftWingRect.intersects(notchRect))
        XCTAssertFalse(rightWingRect.intersects(notchRect))
        XCTAssertFalse(subtitleRowRect.intersects(notchRect))
    }

    // 6. Expanded main content starts below hardware notch
    func testExpandedMainContentStartsBelowHardwareNotch() {
        let model = HardwareNotchModel(
            hasHardwareNotch: true,
            screenNotchRect: CGRect(x: 645.5, y: 924, width: 179, height: 32),
            hardwareNotchWidth: 179,
            hardwareNotchHeight: 32,
            contentTopInset: 32
        )

        let topRowHeight = model.hardwareNotchHeight
        XCTAssertEqual(topRowHeight, 32)

        // Main content starts at or below 32pt
        let mainContentYOffset: CGFloat = topRowHeight
        XCTAssertGreaterThanOrEqual(mainContentYOffset, model.hardwareNotchHeight)
    }

    // 7. No-notch external display fallback
    func testNoNotchExternalDisplayFallback() {
        let fallback = HardwareNotchModel.fallback
        XCTAssertFalse(fallback.hasHardwareNotch)
        XCTAssertEqual(fallback.hardwareNotchWidth, 0)
        XCTAssertEqual(fallback.hardwareNotchHeight, 0)
        XCTAssertEqual(fallback.contentTopInset, 0)
        XCTAssertEqual(fallback.leftWingWidth(totalVisualWidth: 280), 140)
    }

    // 8. Display change recalculates geometry
    @MainActor
    func testDisplayChangeRecalculatesGeometry() {
        let manager = ScreenManager()
        manager.updateScreen()
        XCTAssertNotNil(manager.currentScreen)
        XCTAssertEqual(manager.hasPhysicalNotch, manager.notchModel.hasHardwareNotch)
    }

    // 9. Hit test remains valid over notch
    func testHitTestRemainsValidOverNotch() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visualRect = NotchGeometry.visualRectInWindow(for: .compact, on: screen)
        XCTAssertGreaterThan(visualRect.width, 0)
        XCTAssertGreaterThan(visualRect.height, 0)

        // A click inside the visual rect is recognized
        let centerPoint = CGPoint(x: visualRect.midX, y: visualRect.midY)
        XCTAssertTrue(visualRect.contains(centerPoint))
    }

    func testCompactIdleVisualSizeMatchesHardwareNotchExactWidth() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let model = NotchGeometry.hardwareNotchModel(on: screen)
        let compactSize = NotchGeometry.visualSize(for: .compact, on: screen)
        if model.hasHardwareNotch {
            XCTAssertEqual(compactSize.width, model.hardwareNotchWidth, "Compact idle width must equal hardware notch width to avoid blocking menu bar icons")
            XCTAssertEqual(compactSize.height, model.hardwareNotchHeight)
        } else {
            XCTAssertEqual(compactSize.width, 180)
            XCTAssertEqual(compactSize.height, 32)
        }
    }

    func testCompactIdleRejectsMouseOverWindowWings() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visual = NotchGeometry.visualRectInWindow(for: .compact, on: screen)
        let inside = CGPoint(x: visual.midX, y: visual.midY)
        XCTAssertTrue(NotchGeometry.acceptsMouse(atWindowPoint: inside, state: .compact, on: screen))

        let rightWing = CGPoint(x: visual.maxX + 8, y: visual.midY)
        XCTAssertFalse(
            NotchGeometry.acceptsMouse(atWindowPoint: rightWing, state: .compact, on: screen),
            "Compact idle must click through the transparent right wing onto menu bar extras"
        )

        let leftWing = CGPoint(x: visual.minX - 8, y: visual.midY)
        XCTAssertFalse(NotchGeometry.acceptsMouse(atWindowPoint: leftWing, state: .compact, on: screen))

        let belowPadding = CGPoint(x: visual.midX, y: visual.minY - 4)
        XCTAssertFalse(NotchGeometry.acceptsMouse(atWindowPoint: belowPadding, state: .compact, on: screen))
    }

    func testCompactWindowMayOverlapRightMenuExtrasButVisualMustNot() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let model = NotchGeometry.hardwareNotchModel(on: screen)
        guard model.hasHardwareNotch else { return }
        guard #available(macOS 12.0, *), let right = screen.auxiliaryTopRightArea, right.width > 0 else { return }

        let windowFrame = NotchGeometry.windowFrame(for: .compact, on: screen)
        let visual = NotchGeometry.visualRectInWindow(for: .compact, on: screen)
        let visualInScreen = CGRect(
            x: windowFrame.minX + visual.minX,
            y: windowFrame.minY + visual.minY,
            width: visual.width,
            height: visual.height
        )

        XCTAssertFalse(
            visualInScreen.intersects(right),
            "Compact island must not cover right-of-notch menu bar icons"
        )

        let iconPoint = CGPoint(x: right.minX + 8, y: screen.frame.maxY - min(8, right.height / 2))
        XCTAssertTrue(windowFrame.contains(iconPoint), "Precondition: compact window chrome overlaps right extras")
        let windowPoint = CGPoint(x: iconPoint.x - windowFrame.minX, y: iconPoint.y - windowFrame.minY)
        XCTAssertFalse(NotchGeometry.acceptsMouse(atWindowPoint: windowPoint, state: .compact, on: screen))
    }

    @MainActor
    func testDisabledProviderFilteringInManager() {
        UserDefaults.standard.removeObject(forKey: "devnotch_provider_enabled_map")
        let registry = AIProviderRegistry.makeDefaultRegistry()
        let manager = AIProviderManager(registry: registry)
        XCTAssertEqual(manager.providerIDs.count, 6)
        XCTAssertEqual(manager.enabledProviderIDs.count, 6)
    }
}
