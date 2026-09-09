import AppKit
import SwiftUI
import Combine
import Carbon

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
    let providerManager: AIProviderManager
    let preferences: PreferencesStore
    let systemMetricsStore: SystemMetricsStore
    let nowPlayingStore: NowPlayingStore
    var onOpenSettings: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var localEscMonitor: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    init(
        model: NotchModel = NotchModel(),
        screenManager: ScreenManager = ScreenManager(),
        providerManager: AIProviderManager = AIProviderManager(),
        preferences: PreferencesStore,
        systemMetricsStore: SystemMetricsStore = SystemMetricsStore(),
        nowPlayingStore: NowPlayingStore = NowPlayingStore(),
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.model = model
        self.screenManager = screenManager
        self.providerManager = providerManager
        self.preferences = preferences
        self.systemMetricsStore = systemMetricsStore
        self.nowPlayingStore = nowPlayingStore
        self.onOpenSettings = onOpenSettings

        let initialScreen = screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
        let initialFrame = NotchGeometry.windowFrame(for: .compact, on: initialScreen)
        let panel = NotchPanel(contentRect: initialFrame)

        super.init(window: panel)

        setupContentView(panel: panel)
        setupObservers()
        startClickThroughMonitoring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentView(panel: NotchPanel) {
        let container = NotchContainerView(frame: NSRect(origin: .zero, size: panel.frame.size))
        container.autoresizingMask = [.width, .height]

        let rootView = NotchView(
            model: model,
            screenManager: screenManager,
            providerManager: providerManager,
            preferences: preferences,
            systemMetricsStore: systemMetricsStore,
            nowPlayingStore: nowPlayingStore,
            onOpenSettings: { [weak self] in
                self?.onOpenSettings?()
            }
        )
        let hostingView = NSHostingView(rootView: rootView)

        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        container.hitTestChecker = { [weak self] windowPoint in
            guard let self = self, let screen = self.screenManager.currentScreen else { return true }
            return NotchGeometry.acceptsMouse(atWindowPoint: windowPoint, state: self.model.state, on: screen)
        }

        panel.contentView = container
    }

    private func setupObservers() {
        model.$state
            .removeDuplicates()
            .sink { [weak self] newState in
                guard let self = self else { return }
                self.updateWindowFrame(for: newState, animated: true)
                self.handleOutsideClickMonitoring(for: newState)
                self.handleEscapeKeyMonitoring(for: newState)
                self.updateClickThrough()
            }
            .store(in: &cancellables)


        screenManager.$currentScreen
            .compactMap { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateWindowFrame(for: self.model.state, animated: false)
                self.updateClickThrough()
            }
            .store(in: &cancellables)
    }

    /// Displays the panel above all apps without stealing keyboard focus.
    func showNotchWindow() {
        window?.orderFrontRegardless()
        updateClickThrough()
    }

    /// Expands the notch into full dashboard state.
    func expand() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
            model.state = .expanded
        }
    }

    /// Toggles between compact and expanded states (triggered by Global Hotkey).
    func toggleExpansion() {
        if model.state == .expanded {
            model.collapseToCompact()
        } else {
            expand()
        }
    }

    /// Resizes and repositions the panel frame smoothly to match the target state.
    func updateWindowFrame(for state: NotchState, animated: Bool) {
        guard let window = self.window, let screen = screenManager.currentScreen else { return }
        let targetFrame = NotchGeometry.windowFrame(for: state, on: screen)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = DNTheme.Motion.windowDuration
                context.timingFunction = DNTheme.Motion.windowTiming
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func startClickThroughMonitoring() {
        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    self?.updateClickThrough()
                }
            }
        }
        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor in
                    self?.updateClickThrough()
                }
                return event
            }
        }
        updateClickThrough()
    }

    /// Transparent chrome over menu bar extras must not eat clicks.
    /// AppKit never forwards events when `hitTest` returns nil; toggle `ignoresMouseEvents`.
    private func updateClickThrough() {
        guard let window, let screen = screenManager.currentScreen else { return }
        let pointInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let inside = NotchGeometry.acceptsMouse(atWindowPoint: pointInWindow, state: model.state, on: screen)
        let shouldIgnore = !inside
        if window.ignoresMouseEvents != shouldIgnore {
            window.ignoresMouseEvents = shouldIgnore
        }
        if model.isHovered != inside {
            model.handleHover(inside)
        }
    }

    private func handleOutsideClickMonitoring(for state: NotchState) {
        if state == .expanded {
            if globalClickMonitor == nil {
                globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    Task { @MainActor in
                        guard let self,
                              self.model.state == .expanded,
                              let window = self.window,
                              let screen = self.screenManager.currentScreen else { return }
                        let pointInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
                        let visualRect = NotchGeometry.visualRectInWindow(for: .expanded, on: screen)
                        guard !visualRect.contains(pointInWindow) else { return }
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

    private func handleEscapeKeyMonitoring(for state: NotchState) {
        if state == .expanded {
            if localEscMonitor == nil {
                localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                    if event.keyCode == UInt16(kVK_Escape) {
                        Task { @MainActor in
                            self?.model.collapseToCompact()
                        }
                        return nil
                    }
                    return event
                }
            }
        } else {
            if let monitor = localEscMonitor {
                NSEvent.removeMonitor(monitor)
                localEscMonitor = nil
            }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            if let monitor = self.globalClickMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = self.localEscMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = self.globalMouseMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = self.localMouseMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
