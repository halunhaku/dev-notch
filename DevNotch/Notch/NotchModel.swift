import SwiftUI
import Combine

enum NotchContentMode: String, CaseIterable, Identifiable {
    case ai
    case system
    case music

    var id: Self { self }
}

/// Drives the reactive state and transition animations for Dev Notch.
@MainActor
final class NotchModel: ObservableObject {
    @Published var state: NotchState = .compact
    @Published var isHovered: Bool = false
    @Published var contentMode: NotchContentMode = .ai

    private var autoCollapseTimer: AnyCancellable?
    private var hoverDebounceTimer: AnyCancellable?

    /// Responds to mouse hover state changes on the notch view.
    func handleHover(_ hovered: Bool) {
        self.isHovered = hovered
        hoverDebounceTimer?.cancel()

        if hovered {
            autoCollapseTimer?.cancel()
            if state == .compact {
                withAnimation(DNTheme.Motion.notchAnimation) {
                    state = .hovered
                }
            }
        } else {
            // Mouse exited
            if state == .hovered {
                hoverDebounceTimer = Just(())
                    .delay(for: .milliseconds(350), scheduler: RunLoop.main)
                    .sink { [weak self] in
                        guard let self = self, !self.isHovered, self.state == .hovered else { return }
                        withAnimation(DNTheme.Motion.notchAnimation) {
                            self.state = .compact
                        }
                    }
            } else if state == .expanded {
                startAutoCollapseTimer()
            }
        }
    }

    /// Responds to user click/tap on the notch.
    func handleTap() {
        switch state {
        case .compact, .hovered:
            autoCollapseTimer?.cancel()
            hoverDebounceTimer?.cancel()
            withAnimation(DNTheme.Motion.notchAnimation) {
                state = .expanded
            }
        case .expanded:
            collapseToCompact()
        }
    }

    /// Explicitly collapses the notch back to compact state.
    func collapseToCompact() {
        autoCollapseTimer?.cancel()
        hoverDebounceTimer?.cancel()
        withAnimation(DNTheme.Motion.notchAnimation) {
            state = .compact
        }
    }

    private func startAutoCollapseTimer() {
        autoCollapseTimer?.cancel()
        autoCollapseTimer = Just(())
            .delay(for: .milliseconds(2000), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self = self, !self.isHovered, self.state == .expanded else { return }
                self.collapseToCompact()
            }
    }
}
