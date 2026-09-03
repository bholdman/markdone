import SwiftUI

/// Top-level window content: tab bar, active editor pane, and status bar —
/// or a welcome screen when nothing is open.
struct RootView: View {
    @ObservedObject var store: DocumentStore

    var body: some View {
        VStack(spacing: 0) {
            if store.documents.isEmpty {
                WelcomeView(store: store)
            } else {
                TabBarView(store: store)
                if let doc = store.active {
                    EditorPane(store: store, doc: doc)
                        .id(doc.id)
                    StatusBarView(store: store, doc: doc)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        // Catch files dropped onto the chrome (tab bar, welcome screen, status
        // bar). Drops onto the editor / preview are handled by those views.
        .dropDestination(for: URL.self) { urls, _ in
            store.openFiles(urls)
            return urls.contains { $0.isFileURL }
        }
    }
}

/// Shown when there are no open documents.
private struct WelcomeView: View {
    @ObservedObject var store: DocumentStore

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

            VStack(spacing: 5) {
                Text("MarkDone")
                    .font(.system(size: 26, weight: .bold))
                Text("Capture and preview Markdown, fast.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ActionCard(icon: "square.and.pencil", title: "New Document",
                           subtitle: "⌘N", action: { store.newDocument() })
                ActionCard(icon: "doc.on.clipboard", title: "New from Clipboard",
                           subtitle: "⇧⌘N", action: { store.newFromClipboard() })
                ActionCard(icon: "folder", title: "Open…",
                           subtitle: "⌘O", action: { store.open() })
            }

            shortcutHints
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.accentColor.opacity(0.06), .clear],
                           startPoint: .top, endPoint: .center)
        )
    }

    private var shortcutHints: some View {
        VStack(spacing: 4) {
            Text("Global shortcuts")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                Text("⌥⌘M  New").monospaced()
                Text("⌥⌘V  New from clipboard").monospaced()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}

private struct ActionCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, height: 108)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(hovering ? 0.12 : 0.06),
                            radius: hovering ? 7 : 3, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(hovering ? 0.5 : 0.10), lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
