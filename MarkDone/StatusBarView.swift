import SwiftUI

/// A slim bottom bar showing document info and the view-mode switcher.
struct StatusBarView: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var doc: Document

    var body: some View {
        HStack(spacing: 12) {
            Text(doc.fileURL?.path ?? "Not saved")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Label("\(doc.wordCount) words", systemImage: "textformat")
                .labelStyle(.titleOnly)
                .foregroundStyle(.secondary)
            Text("\(doc.characterCount) chars")
                .foregroundStyle(.secondary)

            viewModeSwitcher
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .frame(height: Theme.statusBarHeight)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var viewModeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases) { mode in
                Button(action: { store.viewMode = mode }) {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(store.viewMode == mode
                                      ? AnyShapeStyle(Color.accentColor.opacity(0.22))
                                      : AnyShapeStyle(Color.clear))
                        )
                        .foregroundStyle(store.viewMode == mode ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(mode.label)
            }
        }
    }
}
