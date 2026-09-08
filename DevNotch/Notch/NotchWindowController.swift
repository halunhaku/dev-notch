import AppKit
import SwiftUI
import Combine

/// Custom NSPanel configured specifically for floating notch overlays.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
    }

    /// Guarantee that Dev Notch never steals keyboard focus from user apps.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Container view isolating NSHostingView from window lifecycle loops and filtering clicks.
final class NotchContainerView: NSView {
    var hitTestChecker: ((NSPoint) -> Bool)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let checker = hitTestChecker {
            guard checker(point) else { return nil }
        }
        return super.hitTest(point)
    }
}

/// Window controller responsible for managing the notch panel, frame resizing, and outside clicks.
@MainActor
final class NotchWindowController: NSWindowController {
    let model: NotchModel
    let screenManager: ScreenManager

    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?

    init(model: NotchModel = NotchModel(), screenManager: ScreenManager = ScreenManager()) {
        self.model = model
        self.screenManager = screenManager

        let initialScreen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
        let initialFrame = NotchGeometry.windowFrame(for: .compact, on: initialScreen)
        let panel = NotchPanel(contentRect: initialFrame)

        super.init(window: panel)

        setupContentView(panel: panel)
        setupObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentView(panel: NotchPanel) {
        let container = NotchContainerView(frame: NSRect(origin: .zero, size: panel.frame.size))
        container.autoresizingMask = [.width, .height]

        let rootView = NotchView(model: model, screenManager: screenManager)
        let hostingView = NSHostingView(rootView: rootView)

        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        container.hitTestChecker = { [weak self] windowPoint in
            guard let self = self, let screen = self.screenManager.currentScreen else { return true }
            let visualRect = NotchGeometry.visualRectInWindow(for: self.model.state, on: screen)
            return visualRect.contains(windowPoint)
        }

        panel.contentView = container
    }

    private func setupObservers() {
        // Observe notch state changes to update window frame and outside click listener
        model.$state
            .removeDuplicates()
            .sink { [weak self] newState in
                guard let self = self else { return }
                self.updateWindowFrame(for: newState, animated: true)
                self.handleOutsideClickMonitoring(for: newState)
            }
            .store(in: &cancellables)

        // Observe screen changes to re-anchor window
        screenManager.$currentScreen
            .compactMap { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateWindowFrame(for: self.model.state, animated: false)
            }
            .store(in: &cancellables)
    }

    /// Displays the panel above all apps without stealing keyboard focus.
    func showNotchWindow() {
        window?.orderFrontRegardless()
    }

    /// Resizes and repositions the panel frame smoothly to match the target state.
    func updateWindowFrame(for state: NotchState, animated: Bool) {
        guard let window = self.window, let screen = screenManager.currentScreen else { return }
        let targetFrame = NotchGeometry.windowFrame(for: state, on: screen)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                // Fluid spring-like timing curve
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func handleOutsideClickMonitoring(for state: NotchState) {
        if state == .expanded {
            if globalClickMonitor == nil {
                globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    guard let self = self, self.model.state == .expanded else { return }
                    Task { @MainActor in
                        self.model.collapseToCompact()
                    }
                }
            }
        } else {
            if let monitor = globalClickMonitor {
                NSEvent.removeMonitor(monitor)
                globalClickMonitor = nil
            }
        }
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
