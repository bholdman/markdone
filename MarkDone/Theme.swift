import SwiftUI

/// Shared visual constants so the app reads as one cohesive, modern design.
enum Theme {
    static let accent = Color.accentColor

    static let tabBarHeight: CGFloat = 38
    static let statusBarHeight: CGFloat = 26
    static let cornerRadius: CGFloat = 6

    static let editorFont = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
    static let editorLineSpacing: CGFloat = 4
    static let editorInset = NSSize(width: 20, height: 18)
}
