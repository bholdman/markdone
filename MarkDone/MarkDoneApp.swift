import SwiftUI

@main
struct MarkDoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        Window("MarkDone", id: "main") {
            RootView(store: store)
                .onAppear { appDelegate.store = store }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { menuCommands }

        MenuBarExtra("MarkDone", image: "MenubarIcon") {
            Button("New Document") { activate(); store.newDocument() }
                .keyboardShortcut("m", modifiers: [.option, .command])
            Button("New from Clipboard") { activate(); store.newFromClipboard() }
                .keyboardShortcut("v", modifiers: [.option, .command])
            Divider()
            Button("Open…") { activate(); store.open() }
            Divider()
            Button("Quit MarkDone") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func activate() { NSApp.activate(ignoringOtherApps: true) }

    @CommandsBuilder
    private var menuCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") { store.newDocument() }
                .keyboardShortcut("n", modifiers: [.command])
            Button("New Tab") { store.newDocument() }
                .keyboardShortcut("t", modifiers: [.command])
            Button("New from Clipboard") { store.newFromClipboard() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Open…") { store.open() }
                .keyboardShortcut("o", modifiers: [.command])
        }
        CommandGroup(after: .newItem) {
            Divider()
            Button("Close Tab") { store.closeActive() }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(store.active == nil)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { store.save() }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(store.active == nil)
            Button("Save As…") { store.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.active == nil)
        }
        CommandMenu("View") {
            Button("Editor Only") { store.viewMode = .editorOnly }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Split") { store.viewMode = .split }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Preview Only") { store.viewMode = .previewOnly }
                .keyboardShortcut("3", modifiers: [.command])
            Divider()
            Button("Next Tab") { store.selectNext() }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(store.documents.count < 2)
            Button("Previous Tab") { store.selectPrevious() }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(store.documents.count < 2)
        }
    }
}

/// App lifecycle: register global hotkeys and seed an initial document.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Assigned once the SwiftUI window appears; flushes any files that
    /// Launch Services asked us to open before then.
    weak var store: DocumentStore? { didSet { flushPendingOpens() } }
    private var pendingURLs: [URL] = []
    private var didOpenFile = false

    /// Files opened via Finder double-click, "Open With", the Dock icon, or the
    /// app being the default handler for .md all arrive here.
    func application(_ application: NSApplication, open urls: [URL]) {
        didOpenFile = true
        NSApp.activate(ignoringOtherApps: true)
        if let store {
            MainActor.assumeIsolated { store.openFiles(urls) }
        } else {
            pendingURLs.append(contentsOf: urls) // window not up yet — buffer
        }
    }

    private func flushPendingOpens() {
        guard let store, !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        MainActor.assumeIsolated { store.openFiles(urls) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.registerDefaults(
            newDocument: { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                self?.store?.newDocument()
            },
            newFromClipboard: { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                self?.store?.newFromClipboard()
            }
        )
        // Start with an empty document ready to type or paste into — unless we
        // were launched to open a file (don't shove an empty tab in front of it).
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didOpenFile,
                  let store = self.store, store.documents.isEmpty else { return }
            store.newDocument()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // stay resident in the menu bar
    }
}
