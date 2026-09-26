import SwiftUI

/// One tile in the category grid — rounded rectangle, title + subtitle, no color beyond
/// system materials. Wrapped in a NavigationLink by the caller, not here, since the
/// destination differs per category.
struct GroupTileView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 84, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Adaptive grid wrapper so category screens don't each re-declare the same layout.
struct TileGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                content
            }
            .padding()
        }
    }
}
