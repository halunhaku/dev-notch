import SwiftUI
import AppKit

/// Generic, non-intrusive horizon pulse line indicating active AI execution.
struct TaskPulseView: View {
    let state: AIActivityState
    let isTransientDone: Bool

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isBreathing: Bool = false

    private var isReduceMotionActive: Bool {
        systemReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var pulseGradient: LinearGradient {
        LinearGradient(
            colors: [Color.cyan.opacity(0.8), Color.blue, Color.cyan.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            if isTransientDone {
                // Success Flash
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green.opacity(0.85))
                    .frame(height: 2)
                    .shadow(color: .green.opacity(0.6), radius: 4, y: 1)
                    .transition(.opacity)
            } else {
                switch state {
                case .working:
                    // Soft Working Pulse
                    RoundedRectangle(cornerRadius: 1)
                        .fill(pulseGradient)
                        .frame(height: 1.5)
                        .shadow(color: .cyan.opacity(0.6), radius: 3, y: 1)
                        .opacity(isReduceMotionActive ? 0.75 : (isBreathing ? 0.95 : 0.35))
                        .animation(
                            isReduceMotionActive
                                ? .default
                                : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isBreathing
                        )
                        .onAppear {
                            if !isReduceMotionActive {
                                isBreathing = true
                            }
                        }

                case .waitingForApproval:
                    // Steady Amber Approval Line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange.opacity(0.9))
                        .frame(height: 1.5)
                        .shadow(color: .orange.opacity(0.5), radius: 3, y: 1)

                case .idle, .completed, .failed:
                    EmptyView()
                }
            }
        }
        .allowsHitTesting(false)
    }
}
