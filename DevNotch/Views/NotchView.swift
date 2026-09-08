import SwiftUI

/// Root visual container for Dev Notch, managing the black island shape,
/// borders, shadows, and state transitions.
struct NotchView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var screenManager: ScreenManager

    private var activeScreen: NSScreen {
        screenManager.currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var visualSize: CGSize {
        NotchGeometry.visualSize(for: model.state, on: activeScreen)
    }

    private var cornerRadius: CGFloat {
        NotchGeometry.cornerRadius(for: model.state)
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Visual Notch Body (anchored flush to the top bezel)
            ZStack {
                // Background & Hardware Bezel Connection
                notchShape
                    .fill(Color.black)
                    .overlay(
                        notchShape
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                    .shadow(
                        color: Color.black.opacity(model.state == .compact ? 0 : 0.45),
                        radius: 12,
                        x: 0,
                        y: 6
                    )

                // State Content
                Group {
                    switch model.state {
                    case .compact:
                        CompactNotchView(model: model, screenManager: screenManager)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    case .hovered:
                        HoveredNotchView(model: model)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    case .expanded:
                        ExpandedNotchView(model: model)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
            .frame(width: visualSize.width, height: visualSize.height)
            .contentShape(notchShape)
            .onHover { isHovered in
                model.handleHover(isHovered)
            }
            .onTapGesture {
                model.handleTap()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: model.state)
    }
}
