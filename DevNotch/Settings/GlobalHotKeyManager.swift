import Foundation
import Carbon
import os.log

private let logger = Logger(subsystem: "com.halunhaku.DevNotch", category: "GlobalHotKey")

/// Protocol defining the interface for global hotkey management.
@MainActor
protocol GlobalHotKeyManaging: AnyObject, Sendable {
    var isRegistered: Bool { get }
    var currentShortcut: KeyboardShortcutDefinition? { get }

    @discardableResult
    func register(shortcut: KeyboardShortcutDefinition, onTrigger: @escaping @MainActor () -> Void) -> Bool
    func unregister()
}

/// Native Carbon-backed Global Hotkey Manager requiring ZERO accessibility or input monitoring permissions.
@MainActor
final class GlobalHotKeyManager: GlobalHotKeyManaging, ObservableObject {
    @Published private(set) var isRegistered: Bool = false
    @Published private(set) var currentShortcut: KeyboardShortcutDefinition?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var triggerCallback: (@MainActor () -> Void)?

    private static let hotKeySignature: OSType = 0x4445564E // 'DEVN'
    private static let hotKeyId: UInt32 = 1

    init() {
        installCarbonEventHandler()
    }

    /// Registers or updates the global shortcut without requiring permissions.
    @discardableResult
    func register(shortcut: KeyboardShortcutDefinition, onTrigger: @escaping @MainActor () -> Void) -> Bool {
        guard shortcut.isValid else {
            logger.warning("Attempted to register invalid shortcut without modifiers: \(shortcut.displayString)")
            return false
        }

        unregister()

        self.triggerCallback = onTrigger
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyId)

        var ref: EventHotKeyRef?
        let err = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if err == noErr, let validRef = ref {
            self.hotKeyRef = validRef
            self.currentShortcut = shortcut
            self.isRegistered = true
            logger.info("Registered global shortcut successfully: \(shortcut.displayString)")
            return true
        } else {
            logger.error("Failed to register global hotkey (OSStatus: \(err))")
            self.isRegistered = false
            return false
        }
    }

    /// Unregisters the current hotkey from the system.
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        self.isRegistered = false
        logger.info("Unregistered global shortcut")
    }

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerUPP: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr && hotKeyID.signature == GlobalHotKeyManager.hotKeySignature {
                Task { @MainActor in
                    manager.triggerCallback?()
                }
            }

            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let err = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerUPP,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        if err != noErr {
            logger.error("Failed to install Carbon event handler (OSStatus: \(err))")
        }
    }

    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }
}
