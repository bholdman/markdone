import SwiftUI
import WebKit

/// Renders Markdown to HTML in a WKWebView (marked.js + highlight.js) and lets the
/// user edit the rendered view directly (contenteditable), converting edits back to
/// Markdown with Turndown.
///
/// Assets are INLINED into one HTML string via `loadHTMLString` (loading local
/// `file://` scripts fails under the App Sandbox), and the sandbox also needs the
/// `com.apple.security.network.client` entitlement for WebKit's networking process.
///
/// Scroll and selection stay in sync with the editor via the shared SyncModel.
struct MarkdownWebView: NSViewRepresentable {
    var markdown: String
    var sync: SyncModel
    var onEdit: (String) -> Void
    /// Called when Markdown/text files are dropped onto the preview.
    var onOpenFiles: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "sync")
        config.userContentController = ucc
        let webView = FileDropWebView(frame: .zero, configuration: config)
        webView.onOpenFiles = onOpenFiles
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(Self.shellHTML, baseURL: nil)

        let coord = context.coordinator
        coord.webView = webView
        sync.scrollPreview = { [weak coord] r in
            if let wv = coord?.webView { coord?.applyScroll(ratio: r, into: wv) }
        }
        sync.selectPreview = { [weak coord] t in
            if let wv = coord?.webView { coord?.applySelection(t, into: wv) }
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coord = context.coordinator
        coord.parent = self
        coord.pending = markdown
        coord.flushIfReady(into: webView)
    }

    // MARK: - Shell

    static let shellHTML: String = buildShell()

    private static func buildShell() -> String {
        func load(_ name: String, _ ext: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                  let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
            return s
        }
        let markedJS = load("marked.min", "js")
        let hljsJS = load("highlight.min", "js")
        let turndownJS = load("turndown.min", "js")
        let turndownGfmJS = load("turndown-plugin-gfm", "js")
        let ghCSS = load("github-markdown", "css")
        let hlLight = load("hl-github.min", "css")
        let hlDark = load("hl-github-dark.min", "css")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(ghCSS)</style>
        <style id="hl-light">\(hlLight)</style>
        <style id="hl-dark" media="not all">\(hlDark)</style>
        <script>\(markedJS)</script>
        <script>\(hljsJS)</script>
        <script>\(turndownJS)</script>
        <script>\(turndownGfmJS)</script>
        <style>
          :root { color-scheme: light dark; }
          html, body { margin: 0; padding: 0; }
          body { background: #ffffff; }
          .markdown-body {
            box-sizing: border-box; max-width: 860px; margin: 0 auto;
            padding: 28px 40px 96px; background: transparent;
            font-size: 15px; line-height: 1.65; outline: none;
          }
          ::selection { background: rgba(124, 58, 237, 0.30); }
          ::highlight(sync) { background-color: rgba(124, 58, 237, 0.32); }
          @media (prefers-color-scheme: dark) {
            body { background: #1e1f22; }
            .markdown-body { color: #e6edf3; }
            .markdown-body a { color: #6cb1ff; }
            .markdown-body h1, .markdown-body h2 { border-bottom-color: #33363b; }
            .markdown-body hr { background-color: #33363b; }
            .markdown-body pre { background-color: #17181b; }
            .markdown-body code:not(pre code) { background-color: rgba(130,138,150,0.28); }
            .markdown-body blockquote { color: #9aa4af; border-left-color: #33363b; }
            .markdown-body table tr { background-color: transparent; border-top-color: #33363b; }
            .markdown-body table th, .markdown-body table td { border-color: #33363b; }
          }
        </style>
        </head>
        <body>
        <article id="content" class="markdown-body" contenteditable="true" spellcheck="false"></article>
        <script>
          (function () {
            var hasHL = (typeof hljs !== 'undefined');
            if (typeof marked !== 'undefined' && marked.setOptions) {
              marked.setOptions({ gfm: true, breaks: false });
            }
            var turndown = null;
            try {
              if (typeof TurndownService !== 'undefined') {
                turndown = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-' });
                if (typeof turndownPluginGfm !== 'undefined') turndown.use(turndownPluginGfm.gfm);
              }
            } catch (e) {}
            function post(m){ try { window.webkit.messageHandlers.sync.postMessage(m); } catch(e){} }
            function highlightAll() {
              if (!hasHL) return;
              document.querySelectorAll('pre code').forEach(function (b) {
                try { hljs.highlightElement(b); } catch (e) {}
              });
            }
            function syncTheme() {
              var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
              document.getElementById('hl-light').media = dark ? 'not all' : 'all';
              document.getElementById('hl-dark').media  = dark ? 'all' : 'not all';
            }
            window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', syncTheme);
            syncTheme();
            var content = document.getElementById('content');

            // Rendering markdown from the editor. `internalEdit` guards the input
            // listener from firing on programmatic DOM updates.
            var internalEdit = false;
            window.render = function (md) {
              internalEdit = true;
              content.innerHTML = (typeof marked !== 'undefined') ? marked.parse(md || '') : (md || '');
              highlightAll();
              setTimeout(function(){ internalEdit = false; }, 0);
            };

            // --- Editing in the preview: convert HTML back to Markdown ---
            var editTimer = null;
            content.addEventListener('input', function () {
              if (internalEdit || !turndown) return;
              clearTimeout(editTimer);
              editTimer = setTimeout(function () {
                try { post({ type: 'edit', markdown: turndown.turndown(content) }); }
                catch (e) {}
              }, 450);
            });

            // --- Scroll sync ---
            var suppressScroll = false, scrollQueued = false;
            window.scrollToRatio = function (r) {
              suppressScroll = true;
              var max = document.documentElement.scrollHeight - window.innerHeight;
              window.scrollTo(0, Math.max(0, max * r));
              setTimeout(function(){ suppressScroll = false; }, 90);
            };
            window.addEventListener('scroll', function () {
              if (suppressScroll || scrollQueued) return;
              scrollQueued = true;
              requestAnimationFrame(function () {
                scrollQueued = false;
                var max = document.documentElement.scrollHeight - window.innerHeight;
                post({ type: 'scroll', ratio: max > 0 ? window.scrollY / max : 0 });
              });
            }, { passive: true });

            // --- Selection sync ---
            // Report the user's preview selection to the editor (empty clears it).
            var suppressSel = false;
            document.addEventListener('selectionchange', function () {
              if (suppressSel) return;
              var t = (window.getSelection() || '').toString();
              post({ type: 'select', text: (t && t.length >= 2) ? t : '' });
            });
            function escapeRe(s){ return s.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'); }
            var canHL = (typeof CSS !== 'undefined' && CSS.highlights && typeof Highlight !== 'undefined');
            // Mirror the editor's selection: find the (whitespace-flexible) text and
            // highlight it via the CSS Custom Highlight API so it shows even when the
            // preview isn't focused. Markdown syntax is stripped to match rendered text.
            window.highlightText = function (str) {
              if (canHL) CSS.highlights.delete('sync');
              if (!str) return;
              var cleaned = str.replace(/[*_`~]/g, '')
                               .replace(/^#{1,6}\\s+/gm, '')
                               .replace(/^\\s*[-+>]\\s+/gm, '')
                               .replace(/^\\s*\\d+\\.\\s+/gm, '');
              var tokens = cleaned.split(/\\s+/).filter(Boolean).map(escapeRe);
              if (!tokens.length) return;
              var re; try { re = new RegExp(tokens.join('\\\\s+')); } catch (e) { return; }
              var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null);
              var nodes = [], full = '', node;
              while ((node = walker.nextNode())) { nodes.push([node, full.length]); full += node.nodeValue; }
              var m = re.exec(full);
              if (!m) return;
              var start = m.index, end = m.index + m[0].length;
              function locate(pos) {
                for (var i = nodes.length - 1; i >= 0; i--) {
                  if (nodes[i][1] <= pos) return [nodes[i][0], pos - nodes[i][1]];
                }
                return [nodes[0][0], 0];
              }
              var s = locate(start), e = locate(end);
              try {
                var range = document.createRange();
                range.setStart(s[0], s[1]); range.setEnd(e[0], e[1]);
                if (canHL) { CSS.highlights.set('sync', new Highlight(range)); }
                else {
                  var sel = window.getSelection();
                  suppressSel = true; sel.removeAllRanges(); sel.addRange(range);
                  setTimeout(function(){ suppressSel = false; }, 120);
                }
                var el = range.startContainer.parentElement;
                if (el && el.scrollIntoView) {
                  suppressScroll = true;
                  el.scrollIntoView({ block: 'center' });
                  setTimeout(function(){ suppressScroll = false; }, 120);
                }
              } catch (e) {}
            };
          })();
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        weak var webView: WKWebView?
        var pending: String = ""
        private var ready = false
        private var lastRendered: String?
        private var lastRatio: Double = -1

        init(_ parent: MarkdownWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            lastRendered = nil
            flushIfReady(into: webView)
        }

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "scroll":
                if let r = body["ratio"] as? Double { parent.sync.reportScroll(r, from: .preview) }
            case "select":
                if let t = body["text"] as? String { parent.sync.reportSelection(t, from: .preview) }
            case "edit":
                if let md = body["markdown"] as? String {
                    // The preview already shows this edit — mark it rendered so the
                    // resulting doc.text change doesn't clobber the user's DOM/cursor.
                    lastRendered = md
                    parent.onEdit(md)
                }
            default: break
            }
        }

        func flushIfReady(into webView: WKWebView) {
            guard ready, pending != lastRendered else { return }
            lastRendered = pending
            webView.evaluateJavaScript("window.render(\(jsString(pending)));", completionHandler: nil)
        }

        func applyScroll(ratio: Double, into webView: WKWebView) {
            guard ready, abs(ratio - lastRatio) > 0.0005 else { return }
            lastRatio = ratio
            webView.evaluateJavaScript("window.scrollToRatio(\(ratio));", completionHandler: nil)
        }

        func applySelection(_ text: String, into webView: WKWebView) {
            guard ready else { return }
            webView.evaluateJavaScript("window.highlightText(\(jsString(text)));", completionHandler: nil)
        }

        private func jsString(_ s: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [s]),
                  let json = String(data: data, encoding: .utf8) else { return "\"\"" }
            return String(json.dropFirst().dropLast())
        }
    }
}

/// WKWebView that opens dropped Markdown/text files as new tabs instead of
/// navigating to them or dropping them into the editable preview.
final class FileDropWebView: WKWebView {
    var onOpenFiles: (([URL]) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerForDraggedTypes([.fileURL])
    }

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
