import SwiftUI
import AppKit
import SiftCore

/// One entry inside a group's detail pane — title, URL, and a password that reveals only
/// while the pointer is over it and copies to the clipboard on click. No separate
/// reveal-gate authentication: matches how the real Passwords app behaves once its own
/// window is unlocked (hover, click, nothing else) — the app-level lock is the only real
/// gate here, by design.
struct PasswordFieldRow: View {
    let entry: PasswordEntry

    @State private var isHovering = false
    @State private var justCopied = false
    @Environment(\.openURL) private var openURL

    private static let mask = "••••••••"

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                if let url = entry.url {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(justCopied ? "Copied" : (isHovering ? entry.password : Self.mask))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isHovering || justCopied ? .primary : .secondary)
                .onHover { hovering in
                    isHovering = hovering
                }
                .onTapGesture {
                    copyToClipboard(entry.password)
                }
                .help("Click to copy")

            if let url = entry.url, isOpenable(url) {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
                .help("Open in browser")
            }
        }
    }

    /// Only http/https — a crafted CSV row shouldn't be able to smuggle another URL
    /// scheme through this button.
    private func isOpenable(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        return scheme == "http" || scheme == "https"
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            justCopied = false
        }
    }
}
