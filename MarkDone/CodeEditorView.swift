import SwiftUI
import AppKit

/// A plain-text Markdown editor backed by NSTextView — monospaced, comfortable
/// line spacing, stable for large docs, and kept in sync (scroll + selection)
/// with the preview pane via the shared SyncModel.
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var focusToken: Int
    var sync: SyncModel
    /// Called when Markdown/text files are dropped onto the editor.
    var onOpenFiles: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Build the text view by hand (rather than NSTextView.scrollableTextView())
        // so we can use a subclass that opens dropped files as new tabs.
        let contentSize = scrollView.contentSize
        let textView = FileDropTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.onOpenFiles = onOpenFiles
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.font = Theme.editorFont
        textView.textColor = .labelColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = Theme.editorInset
        textView.autoresizingMask = [.width]
        textView.defaultParagraphStyle = context.coordinator.paragraphStyle
        textView.typingAttributes = context.coordinator.typingAttributes

        let coord = context.coordinator
        coord.textView = textView
        coord.scrollView = scrollView

        // Register appliers so the preview can drive this pane directly.
        sync.scrollEditor = { [weak coord] r in coord?.applyScroll(ratio: r) }
        sync.selectEditor = { [weak coord] t in coord?.applySelection(t) }

        NotificationCenter.default.addObserver(
            coord, selector: #selector(Coordinator.boundsChanged),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        scrollView.contentView.postsBoundsChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coord = context.coordinator
        coord.parent = self

        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            textView.typingAttributes = coord.typingAttributes
            let safe = NSRange(location: min(selected.location, text.utf16.count), length: 0)
            textView.setSelectedRange(safe)
        }

        if coord.lastFocusToken != focusToken {
            coord.lastFocusToken = focusToken
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var lastFocusToken = -1
        private var suppressScroll = false
        private var suppressSelection = false
        private var scrollThrottled = false
        private var trailingRatio: Double?

        let paragraphStyle: NSParagraphStyle = {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = Theme.editorLineSpacing
            return p
        }()
        var typingAttributes: [NSAttributedString.Key: Any] {
            [.font: Theme.editorFont, .foregroundColor: NSColor.labelColor,
             .paragraphStyle: paragraphStyle]
        }

        init(_ parent: CodeEditorView) { self.parent = parent }

        // MARK: Reporting user actions

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !suppressSelection, let tv = textView else { return }
            let range = tv.selectedRange()
            let s = tv.string as NSString
            // Report the selected text (empty clears the preview highlight).
            parent.sync.reportSelection(range.length >= 2 ? s.substring(with: range) : "", from: .editor)
        }

        @objc func boundsChanged() {
            guard !suppressScroll, let scrollView, let doc = scrollView.documentView else { return }
            let visible = scrollView.contentView.bounds
            let maxScroll = doc.frame.height - visible.height
            guard maxScroll > 0 else { return }
            reportScrollThrottled(min(1, max(0, visible.origin.y / maxScroll)))
        }

        /// Coalesce scroll reports to ~60 Hz so the preview updates smoothly.
        private func reportScrollThrottled(_ ratio: Double) {
            if scrollThrottled { trailingRatio = ratio; return }
            scrollThrottled = true
            parent.sync.reportScroll(ratio, from: .editor)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) { [weak self] in
                guard let self else { return }
                self.scrollThrottled = false
                if let t = self.trailingRatio { self.trailingRatio = nil; self.reportScrollThrottled(t) }
            }
        }

        // MARK: Applying changes from the preview

        func applyScroll(ratio: Double) {
            guard let scrollView, let doc = scrollView.documentView else { return }
            let visible = scrollView.contentView.bounds
            let maxScroll = doc.frame.height - visible.height
            guard maxScroll > 0 else { return }
            suppressScroll = true
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: ratio * maxScroll))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.suppressScroll = false }
        }

        func applySelection(_ text: String) {
            guard let tv = textView else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { return }
            // Match the words separated by any run of whitespace, so a multi-line
            // rendered selection maps onto the differently-wrapped source text.
            let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .map { NSRegularExpression.escapedPattern(for: $0) }
            guard !tokens.isEmpty,
                  let re = try? NSRegularExpression(pattern: tokens.joined(separator: "\\s+")) else { return }
            let haystack = tv.string as NSString
            guard let match = re.firstMatch(in: tv.string, range: NSRange(location: 0, length: haystack.length)),
                  match.range.location != NSNotFound else { return }
            suppressSelection = true; suppressScroll = true
            tv.setSelectedRange(match.range)
            tv.scrollRangeToVisible(match.range)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.suppressSelection = false; self.suppressScroll = false
            }
        }
    }
}

/// NSTextView that opens dropped Markdown/text files as new tabs instead of
/// inserting their contents, while leaving ordinary text/image drags to the
/// superclass.
final class FileDropTextView: NSTextView {
    var onOpenFiles: (([URL]) -> Void)?

    private func droppedFileURLs(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFileURLs(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFileURLs(sender).isEmpty ? super.draggingUpdated(sender) : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedFileURLs(sender).isEmpty ? super.prepareForDragOperation(sender) : true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = droppedFileURLs(sender)
        guard !urls.isEmpty else { return super.performDragOperation(sender) }
        onOpenFiles?(urls)
        return true
    }
}
