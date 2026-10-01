import SwiftUI

/// A small drawn mock of the Passwords app's menu bar + File menu, with the export item
/// highlighted. Deliberately NOT a real screenshot or recording — this is plain SwiftUI
/// shapes and text, so it's immune to the AVKit/VideoPlayer crash that replaced it, stays
/// theme-adaptive for free via system colors, and costs nothing in bundle size.
struct ExportMenuHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                menuBarRow

                // A separate floating card, not fused to the bar — real macOS menus open
                // as their own popover below the menu bar, with a visible gap and shadow,
                // left-aligned under the clicked item rather than spanning/centered under
                // the whole bar.
                VStack(spacing: 0) {
                    menuRow("New Password…")
                    menuRow("New Window")
                    menuRow("New Shared Group…")
                    Divider().padding(.vertical, 2)
                    menuRow("Import Passwords from File…")
                    Divider().padding(.vertical, 2)
                    menuRow("Export All Items to App…")
                    menuRow("Export All Passwords to File…", highlighted: true)
                }
                .padding(.vertical, 6)
                .frame(width: 230)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                // Lines the dropdown's left edge up with "File"'s left edge in the bar
                // above, instead of the whole card centered under the mock.
                .padding(.leading, fileLabelLeadingOffset)
            }

            Text("Passwords app → File → Export All Passwords to File…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Approximate x-position where "File" starts in menuBarRow below — icon + spacing +
    /// "Passwords" + spacing. Not measured dynamically (this is a static mock, not a real
    /// menu), just close enough to read as aligned.
    private let fileLabelLeadingOffset: CGFloat = 74

    /// The macOS menu bar itself, shown above the dropdown so it reads as a system menu
    /// bar item (always at the top of the screen) rather than something inside Sift.
    private var menuBarRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo")
                .font(.system(size: 9))
            Text("Passwords")
                .fontWeight(.bold)
            Text("File")
                .fontWeight(.bold)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text("Edit")
            Text("View")
            Text("Window")
            Text("Help")
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .lineLimit(1)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 320)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .bottom)
    }

    private func menuRow(_ title: String, highlighted: Bool = false) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(highlighted ? .semibold : .regular)
            .foregroundStyle(highlighted ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? Color.accentColor : Color.clear)
    }
}
