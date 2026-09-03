import SwiftUI

/// A modern browser-style tab strip for the open documents.
struct TabBarView: View {
    @ObservedObject var store: DocumentStore

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.documents) { doc in
                        TabItemView(
                            doc: doc,
                            isActive: doc.id == store.activeID,
                            onSelect: { store.activeID = doc.id },
                            onClose: { store.close(doc) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            Divider().frame(height: 18)

            Button(action: { store.newDocument() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: Theme.tabBarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("New document (⌘T)")
        }
        .frame(height: Theme.tabBarHeight)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct TabItemView: View {
    @ObservedObject var doc: Document
    var isActive: Bool
    var onSelect: () -> Void
    var onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            leadingGlyph
            Text(doc.displayName)
                .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .padding(.leading, 11)
        .padding(.trailing, 9)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(isActive ? AnyShapeStyle(.background) : AnyShapeStyle(Color.clear))
                .shadow(color: isActive ? .black.opacity(0.10) : .clear, radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isActive ? 0.06 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
        .frame(maxWidth: 200)
    }

    /// Shows a close button on hover; otherwise a dirty dot (or nothing).
    @ViewBuilder
    private var leadingGlyph: some View {
        if hovering {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(Color.primary.opacity(0.10)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close tab")
        } else if doc.isDirty {
            Circle().fill(Color.secondary).frame(width: 7, height: 7)
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 15, height: 15)
        }
    }
}
