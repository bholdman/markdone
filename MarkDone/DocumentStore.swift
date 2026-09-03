import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// How the editor / preview panes are arranged.
enum ViewMode: Int, CaseIterable, Identifiable {
    case editorOnly, split, previewOnly
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .editorOnly: return "Editor"
        case .split: return "Split"
        case .previewOnly: return "Preview"
        }
    }
    var systemImage: String {
        switch self {
        case .editorOnly: return "doc.plaintext"
        case .split: return "rectangle.split.2x1"
        case .previewOnly: return "eye"
        }
    }
}

/// Owns all open documents (tabs) and the shared view state.
@MainActor
final class DocumentStore: ObservableObject {
    @Published var documents: [Document] = []
    @Published var activeID: Document.ID?
    @Published var viewMode: ViewMode = .split

    private let markdownType = UTType(filenameExtension: "md") ?? .plainText

    var active: Document? { documents.first { $0.id == activeID } }

    // MARK: - Creating tabs

    @discardableResult
    func newDocument(text: String = "", fileURL: URL? = nil, isDirty: Bool = false) -> Document {
        let doc = Document(text: text, fileURL: fileURL, isDirty: isDirty)
        documents.append(doc)
        activeID = doc.id
        doc.requestFocus()
        return doc
    }

    func newFromClipboard() {
        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        newDocument(text: clip, isDirty: !clip.isEmpty)
    }

    // MARK: - Opening

    func open() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [markdownType, .plainText, .text]
        if panel.runModal() == .OK {
            for url in panel.urls { openFile(url) }
        }
    }

    /// File extensions we'll open (used to filter dragged-in files).
    static let openableExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "markdn",
        "mdtext", "mdtxt", "text", "txt"
    ]

    /// Open one or more files (e.g. dropped onto the window or passed by Launch
    /// Services), each in its own tab. Non-text files are ignored.
    func openFiles(_ urls: [URL]) {
        for url in urls where url.isFileURL {
            let ext = url.pathExtension.lowercased()
            if ext.isEmpty || Self.openableExtensions.contains(ext) {
                openFile(url)
            }
        }
    }

    func openFile(_ url: URL) {
        // Focus an already-open tab for the same file instead of duplicating it.
        if let existing = documents.first(where: { $0.fileURL == url }) {
            activeID = existing.id
            return
        }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            newDocument(text: contents, fileURL: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            presentError(error, context: "Could not open “\(url.lastPathComponent)”.")
        }
    }

    // MARK: - Saving

    @discardableResult
    func save(_ doc: Document? = nil) -> Bool {
        guard let doc = doc ?? active else { return false }
        guard let url = doc.fileURL else { return saveAs(doc) }
        return write(doc, to: url)
    }

    @discardableResult
    func saveAs(_ doc: Document? = nil) -> Bool {
        guard let doc = doc ?? active else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [markdownType]
        panel.nameFieldStringValue = suggestedFileName(for: doc)
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            return write(doc, to: url)
        }
        return false
    }

    @discardableResult
    private func write(_ doc: Document, to url: URL) -> Bool {
        do {
            try doc.text.write(to: url, atomically: true, encoding: .utf8)
            doc.fileURL = url
            doc.isDirty = false
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            return true
        } catch {
            presentError(error, context: "Could not save “\(url.lastPathComponent)”.")
            return false
        }
    }

    // MARK: - Closing

    func close(_ doc: Document) {
        if doc.isDirty && !confirmDiscard(doc) { return }
        guard let idx = documents.firstIndex(where: { $0.id == doc.id }) else { return }
        documents.remove(at: idx)
        if activeID == doc.id {
            let next = documents.indices.contains(idx) ? documents[idx] : documents.last
            activeID = next?.id
        }
    }

    func closeActive() {
        if let doc = active { close(doc) }
    }

    // MARK: - Tab navigation

    func selectNext() { step(1) }
    func selectPrevious() { step(-1) }
    private func step(_ delta: Int) {
        guard !documents.isEmpty,
              let idx = documents.firstIndex(where: { $0.id == activeID }) else { return }
        let next = (idx + delta + documents.count) % documents.count
        activeID = documents[next].id
    }

    // MARK: - Helpers

    private func suggestedFileName(for doc: Document) -> String {
        for rawLine in doc.text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { return sanitize(title) + ".md" }
            }
        }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmmss"
        return "note-\(f.string(from: Date())).md"
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return String(name.components(separatedBy: invalid).joined(separator: "-").prefix(80))
    }

    private func confirmDiscard(_ doc: Document) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to “\(doc.displayName)”?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save(doc)
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    private func presentError(_ error: Error, context: String) {
        let alert = NSAlert()
        alert.messageText = context
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
