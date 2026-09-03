import SwiftUI

@main
struct MarkDoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        Window("MarkDone", id: "main") {
            MainWindowContent(store: store, appDelegate: appDelegate)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { menuCommands }

    }

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

/// Hosts RootView inside the main window and hands the app delegate the two
/// things it can't reach on its own: the document store and SwiftUI's
/// `openWindow` action (needed to bring the window back after it's closed).
private struct MainWindowContent: View {
    @ObservedObject var store: DocumentStore
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RootView(store: store)
            .onAppear {
                appDelegate.store = store
                appDelegate.openMainWindow = { openWindow(id: "main") }
            }
    }
}

/// App lifecycle: register global hotkeys and seed an initial document.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Assigned once the SwiftUI window appears; flushes any files that
    /// Launch Services asked us to open before then.
    weak var store: DocumentStore? { didSet { flushPendingOpens() } }
    /// SwiftUI's `openWindow(id: "main")`, captured from the window content.
    /// Reopens the window if the user closed it; just fronts it otherwise.
    var openMainWindow: (() -> Void)?
    private var pendingURLs: [URL] = []
    private var didOpenFile = false

    /// Bring MarkDone to the front with its main window visible. Safe to call
    /// from a global hotkey or the menu bar while another app is active, and
    /// when the window has been closed (the app stays resident in the menu bar).
    func showMainWindow() {
        // `activate(ignoringOtherApps:)` is deprecated on macOS 14 and frequently
        // does nothing when another app is frontmost; the new API cooperates with
        // the system's activation rules and works from a hotkey.
        NSApp.activate()
        openMainWindow?()
        DispatchQueue.main.async {
            NSApp.activate()
            let main = NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }
                ?? NSApp.windows.first { $0.canBecomeMain && $0.title == "MarkDone" }
            main?.makeKeyAndOrderFront(nil)
        }
    }

    /// Show the window, then run `action` against the store once the window's
    /// views exist so a new document lands in a visible, focusable editor.
    func summon(_ action: @escaping @MainActor (DocumentStore) -> Void) {
        showMainWindow()
        DispatchQueue.main.async { [weak self] in
            guard let store = self?.store else { return }
            MainActor.assumeIsolated { action(store) }
        }
    }

    /// Files opened via Finder double-click, "Open With", the Dock icon, or the
    /// app being the default handler for .md all arrive here.
    func application(_ application: NSApplication, open urls: [URL]) {
        didOpenFile = true
        showMainWindow()
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
        installStatusItem()
        HotKeyManager.shared.registerDefaults(
            newDocument: { [weak self] in self?.summon { $0.newDocument() } },
            newFromClipboard: { [weak self] in self?.summon { $0.newFromClipboard() } }
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

    // MARK: - Menu bar status item

    // An AppKit NSStatusItem rather than SwiftUI's MenuBarExtra so we can tell
    // clicks apart: a single click (or right-click) opens the quick-actions menu,
    // a double-click shows the app. MenuBarExtra can't distinguish these.
    private var statusItem: NSStatusItem?
    /// Menu presentation deferred by one double-click interval after a single
    /// left click, so a second click can cancel it and show the app instead.
    private var pendingMenu: DispatchWorkItem?

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(named: "MenubarIcon")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "MarkDone — click for actions, double-click to show"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector, key: String = "", mods: NSEvent.ModifierFlags = []) {
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
            mi.keyEquivalentModifierMask = mods
            mi.target = self
            menu.addItem(mi)
        }
        add("Show MarkDone", #selector(menuShow))
        menu.addItem(.separator())
        // Key equivalents here are labels only; the Carbon hotkeys do the work.
        add("New Document", #selector(menuNewDocument), key: "m", mods: [.option, .command])
        add("New from Clipboard", #selector(menuNewFromClipboard), key: "v", mods: [.option, .command])
        add("Open…", #selector(menuOpen), key: "o", mods: [.command])
        menu.addItem(.separator())
        add("Quit MarkDone", #selector(menuQuit), key: "q", mods: [.command])
        return menu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        pendingMenu?.cancel()
        pendingMenu = nil

        let isSecondary = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isSecondary {
            showStatusMenu(from: sender)
        } else if event.clickCount >= 2 {
            showMainWindow()
        } else {
            // Single left click: open the menu unless a second click arrives first.
            let work = DispatchWorkItem { [weak self, weak sender] in
                guard let self, let sender else { return }
                self.pendingMenu = nil
                self.showStatusMenu(from: sender)
            }
            pendingMenu = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
        }
    }

    private func showStatusMenu(from button: NSStatusBarButton) {
        // Attach the menu only for the duration of this presentation so later
        // clicks come back to us as actions rather than opening it directly.
        statusItem?.menu = makeStatusMenu()
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuShow() { showMainWindow() }
    @objc private func menuNewDocument() { summon { $0.newDocument() } }
    @objc private func menuNewFromClipboard() { summon { $0.newFromClipboard() } }
    @objc private func menuOpen() { summon { $0.open() } }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}
