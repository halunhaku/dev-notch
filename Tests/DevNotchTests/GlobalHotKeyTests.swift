import XCTest
@testable import DevNotch

final class MockGlobalHotKeyManager: GlobalHotKeyManaging {
    var isRegistered: Bool = false
    var currentShortcut: KeyboardShortcutDefinition?
    var triggerCallback: (@MainActor () -> Void)?
    var shouldFailRegistration: Bool = false

    func register(shortcut: KeyboardShortcutDefinition, onTrigger: @escaping @MainActor () -> Void) -> Bool {
        if shouldFailRegistration {
            isRegistered = false
            return false
        }
        self.currentShortcut = shortcut
        self.triggerCallback = onTrigger
        self.isRegistered = true
        return true
    }

    func unregister() {
        self.isRegistered = false
        self.currentShortcut = nil
        self.triggerCallback = nil
    }

    func simulateHotkeyPress() {
        triggerCallback?()
    }
}

@MainActor
final class GlobalHotKeyTests: XCTestCase {
    func testHotkeyTogglesCompactToExpandedAndBack() {
        let mockHotKey = MockGlobalHotKeyManager()
        let model = NotchModel()

        XCTAssertEqual(model.state, .compact)

        // Register hotkey callback
        let registered = mockHotKey.register(shortcut: .defaultToggleNotch) {
            if model.state == .expanded {
                model.collapseToCompact()
            } else {
                model.state = .expanded
            }
        }
        XCTAssertTrue(registered)
        XCTAssertTrue(mockHotKey.isRegistered)

        // 1. First trigger: compact -> expanded
        mockHotKey.simulateHotkeyPress()
        XCTAssertEqual(model.state, .expanded)

        // 2. Second trigger: expanded -> compact
        mockHotKey.simulateHotkeyPress()
        XCTAssertEqual(model.state, .compact)
    }

    func testHotkeyRegistrationFailureHandling() {
        let mockHotKey = MockGlobalHotKeyManager()
        mockHotKey.shouldFailRegistration = true

        let registered = mockHotKey.register(shortcut: .defaultToggleNotch) {}
        XCTAssertFalse(registered)
        XCTAssertFalse(mockHotKey.isRegistered)
    }

    func testHotkeyUnregistration() {
        let mockHotKey = MockGlobalHotKeyManager()
        _ = mockHotKey.register(shortcut: .defaultToggleNotch) {}
        XCTAssertTrue(mockHotKey.isRegistered)

        mockHotKey.unregister()
        XCTAssertFalse(mockHotKey.isRegistered)
        XCTAssertNil(mockHotKey.currentShortcut)
    }
}
