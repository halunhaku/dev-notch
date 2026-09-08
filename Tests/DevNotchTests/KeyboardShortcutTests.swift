import XCTest
import Carbon
import AppKit
@testable import DevNotch

final class KeyboardShortcutTests: XCTestCase {
    func testDefaultShortcutDefinition() {
        let def = KeyboardShortcutDefinition.defaultToggleNotch
        XCTAssertEqual(def.keyCode, UInt32(kVK_Space))
        XCTAssertTrue(def.isValid)
        XCTAssertEqual(def.displayString, "⌃⌥Space")
    }

    func testShortcutSerialization() throws {
        let original = KeyboardShortcutDefinition(
            keyCode: UInt32(kVK_ANSI_N),
            carbonModifiers: UInt32(controlKey | optionKey)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyboardShortcutDefinition.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.displayString, "⌃⌥N")
    }

    func testInvalidNoModifierShortcutsRejected() {
        // Bare Space key without modifiers
        let bareSpace = KeyboardShortcutDefinition(keyCode: UInt32(kVK_Space), carbonModifiers: 0)
        XCTAssertFalse(bareSpace.isValid)

        // Bare Return key
        let bareReturn = KeyboardShortcutDefinition(keyCode: UInt32(kVK_Return), carbonModifiers: 0)
        XCTAssertFalse(bareReturn.isValid)

        // Bare letter A
        let bareA = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: 0)
        XCTAssertFalse(bareA.isValid)

        // Shift only without Command/Option/Control (also rejected per Section 22)
        let shiftOnly = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(shiftKey))
        XCTAssertFalse(shiftOnly.isValid)

        // Valid with Command
        let withCmd = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(cmdKey))
        XCTAssertTrue(withCmd.isValid)

        // Valid with Option
        let withOpt = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(optionKey))
        XCTAssertTrue(withOpt.isValid)

        // Valid with Control
        let withCtrl = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(controlKey))
        XCTAssertTrue(withCtrl.isValid)
    }

    func testCarbonModifiersFromCocoa() {
        let flags: NSEvent.ModifierFlags = [.command, .option]
        let mods = KeyboardShortcutDefinition.carbonModifiers(from: flags)
        XCTAssertNotEqual(mods & UInt32(cmdKey), 0)
        XCTAssertNotEqual(mods & UInt32(optionKey), 0)
        XCTAssertEqual(mods & UInt32(controlKey), 0)
    }
}
