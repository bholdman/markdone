import SwiftUI

/// Coordinates scroll, selection, and edits between the editor and preview panes
/// for a single document. Uses direct closures rather than @Published state so a
/// stream of scroll events doesn't trigger SwiftUI re-renders (which made
/// editor→preview scrolling jerky). Each pane registers appliers; a report from
/// one pane invokes the *other* pane's applier, so nothing echoes back.
final class SyncModel: ObservableObject {
    enum Pane { case editor, preview }

    // Appliers registered by each pane. Invoked to mirror the other pane's action.
    var scrollEditor: ((Double) -> Void)?
    var scrollPreview: ((Double) -> Void)?
    var selectEditor: ((String) -> Void)?
    var selectPreview: ((String) -> Void)?

    func reportScroll(_ ratio: Double, from pane: Pane) {
        (pane == .editor ? scrollPreview : scrollEditor)?(ratio)
    }

    func reportSelection(_ text: String, from pane: Pane) {
        (pane == .editor ? selectPreview : selectEditor)?(text)
    }
}
