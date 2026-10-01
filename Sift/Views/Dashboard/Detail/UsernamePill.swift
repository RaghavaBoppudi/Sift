import SwiftUI
import SiftCore

/// One card for one username: User Name, Password, Website, matching Apple's single-item
/// card minus the icon (no network access means no favicons). When one username has several
/// URLs sharing ONE password it collapses to "host and N more"; with genuinely different
/// passwords it lists each URL/password pair separately.
struct UsernamePill: View {
    let username: String
    let entries: [PasswordEntry]
    @Environment(\.openURL) private var openURL

    private var hasSinglePassword: Bool {
        Set(entries.filter(\.hasUsablePassword).map(\.password)).count <= 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow("User Name") {
                Text(username.isEmpty ? "—" : username).textSelection(.enabled)
            }

            if hasSinglePassword {
                fieldRow("Password") { RevealablePassword(password: entries.first?.password ?? "") }
                fieldRow("Website") { websiteValue(entries) }
                notesRows(for: entries)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider() }
                    fieldRow("Website") { websiteValue([entry]) }
                    fieldRow("Password") { RevealablePassword(password: entry.password) }
                    notesRows(for: [entry])
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func websiteValue(_ entries: [PasswordEntry]) -> some View {
        let urls = entries.compactMap(\.url)

        if urls.count > 1 {
            Menu {
                ForEach(urls, id: \.self) { url in
                    if isOpenable(url) {
                        Button(url.host ?? url.absoluteString) { openURL(url) }
                    } else {
                        Text(url.host ?? url.absoluteString)
                    }
                }
            } label: {
                Text("\(urls[0].host ?? urls[0].absoluteString) and \(urls.count - 1) more")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else if let only = urls.first {
            HStack(spacing: 6) {
                Text(only.host ?? only.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isOpenable(only) {
                    Button {
                        openURL(only)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                }
            }
        } else {
            Text("—")
        }
    }

    /// http/https only: a crafted CSV row must not be able to smuggle another URL scheme
    /// through this button.
    private func isOpenable(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }

    @ViewBuilder
    private func notesRows(for entries: [PasswordEntry]) -> some View {
        ForEach(entries.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { entry in
            fieldRow("Notes") { Text(entry.notes).textSelection(.enabled) }
        }
    }
}
