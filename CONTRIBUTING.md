# Contributing to MarkDone

Thanks for your interest! MarkDone is a small app and contributions of every size are welcome — bug reports, feature ideas, docs fixes, and code.

## Ground rules

- Keep it lightweight. MarkDone exists because other editors felt heavy; a feature that adds a big dependency or a lot of UI needs a strong reason.
- Stay offline-first. The preview bundles and inlines all its assets; don't introduce network calls.
- Open an issue before starting a large change so we can agree on the approach.

## Development setup

Requires Xcode 15 or later (macOS 14 deployment target).

```sh
git clone https://github.com/bholdman/markdone.git
cd markdone
xcodebuild -project MarkDone.xcodeproj -scheme MarkDone -configuration Debug -derivedDataPath build
open build/Build/Products/Debug/MarkDone.app
```

Or open `MarkDone.xcodeproj` in Xcode and press ⌘R. `examples/sample.md` is a handy document for exercising the preview.

### The Xcode project is generated

`MarkDone.xcodeproj/project.pbxproj` is produced by `scripts/genproj.py`. If you add, remove, or rename a Swift source or resource file, or change a build setting, edit the script and regenerate:

```sh
python3 scripts/genproj.py
```

Don't hand-edit `project.pbxproj`; your change will be lost on the next regenerate.

### Things that are easy to break

- **Blank preview.** The WKWebView preview only renders inside the sandbox when the HTML is loaded as a single inlined string *and* the `com.apple.security.network.client` entitlement is present. Don't remove that entitlement.
- **Jerky scroll sync.** Scroll and selection sync go through direct closures on `SyncModel`, not `@Published` state, so a stream of scroll events doesn't re-render the view tree. Keep it that way.
- **Preview editing.** Edits in the preview round-trip through Turndown and normalize Markdown formatting. That's expected; don't try to make it byte-preserving.

## Pull requests

1. Fork and branch from `main`.
2. Make sure a Debug build succeeds with no new warnings.
3. Exercise the change in the running app: both view panes, light and dark mode, and a file opened from Finder if it touches file handling.
4. Describe *what* changed and *why* in the PR. Screenshots or a short recording help a lot for UI changes.

## Reporting bugs

Please include your macOS version, what you did, what you expected, and what happened instead. A minimal Markdown snippet that reproduces a rendering or sync issue is gold.

## A note on how this code was written

The Swift in this repo was written by AI under human direction and review. That doesn't change the bar for contributions: PRs are judged on whether they work, read clearly, and keep the app small. Human-written, AI-assisted, or AI-written contributions are all welcome as long as you've run and tested them yourself.
