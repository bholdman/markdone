import SwiftUI

/// The editor + preview split for a single active document. Scroll, selection,
/// and edits are kept in sync between the two panes (both are editable).
struct EditorPane: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var doc: Document
    @StateObject private var sync = SyncModel()

    var body: some View {
        Group {
            switch store.viewMode {
            case .editorOnly:
                editor
            case .previewOnly:
                preview
            case .split:
                HSplitView {
                    editor.frame(minWidth: 300)
                    preview.frame(minWidth: 300)
                }
            }
        }
    }

    private var editor: some View {
        CodeEditorView(
            text: Binding(get: { doc.text }, set: { doc.text = $0; doc.isDirty = true }),
            focusToken: doc.focusToken,
            sync: sync,
            onOpenFiles: { store.openFiles($0) }
        )
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var preview: some View {
        MarkdownWebView(
            markdown: doc.text,
            sync: sync,
            onEdit: { doc.text = $0; doc.isDirty = true },
            onOpenFiles: { store.openFiles($0) }
        )
    }
}
