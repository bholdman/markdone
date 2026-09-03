import SwiftUI

/// A single open Markdown document (one tab).
@MainActor
final class Document: ObservableObject, Identifiable {
    let id = UUID()
    @Published var text: String
    @Published var fileURL: URL?
    @Published var isDirty: Bool

    /// Bumped to ask the editor to take keyboard focus (new doc / paste).
    @Published var focusToken: Int = 0
    /// Editor scroll position (0–1), used to drive preview scroll sync.
    @Published var scrollRatio: Double = 0

    init(text: String = "", fileURL: URL? = nil, isDirty: Bool = false) {
        self.text = text
        self.fileURL = fileURL
        self.isDirty = isDirty
    }

    var displayName: String { fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled" }

    var wordCount: Int {
        text.split { $0 == " " || $0.isNewline || $0 == "\t" }.count
    }

    var characterCount: Int { text.count }

    func requestFocus() { focusToken &+= 1 }
}
