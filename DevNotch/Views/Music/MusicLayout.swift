import SwiftUI

enum MusicLayout {
    static let cardRadius: CGFloat = 22
    static let cardPadding: CGFloat = 12
    static let artwork: CGFloat = 148
    static let artworkCorner: CGFloat = 12
    static let playButton: CGFloat = 44
    static let skipButton: CGFloat = 32
    static let progressHeight: CGFloat = 4

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }

    static var hoverAnimation: Animation {
        DNTheme.Motion.reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.16)
    }

}
