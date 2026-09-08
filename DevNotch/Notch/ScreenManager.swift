import AppKit
import Combine

/// Monitors display parameters, detects physical notch, and tracks screen metrics.
@MainActor
final class ScreenManager: ObservableObject {
    @Published private(set) var currentScreen: NSScreen?
    @Published private(set) var hasPhysicalNotch: Bool = false
    @Published private(set) var notchRect: CGRect = .zero

    private var cancellables = Set<AnyCancellable>()

    init() {
        updateScreen()
        setupNotification()
    }

    /// Refresh screen metrics and notch geometry based on the active main screen.
    func updateScreen() {
        // Priority: screen with key window or NSScreen.main, fallback to screens.first
        let screen = NSScreen.main ?? NSScreen.screens.first
        self.currentScreen = screen

        guard let screen = screen else {
            self.hasPhysicalNotch = false
            self.notchRect = .zero
            return
        }

        self.hasPhysicalNotch = NotchGeometry.hasNotch(on: screen)
        self.notchRect = NotchGeometry.notchBounds(on: screen)
    }

    private func setupNotification() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateScreen()
            }
            .store(in: &cancellables)
    }
}
