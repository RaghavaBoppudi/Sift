import SwiftUI
import AppKit
import SiftCore

/// Shown in the detail column when a Duplicate Passwords row is selected. A conflict
/// group is always exactly one username by construction, so this is always exactly one
/// pill — built through the same UsernamePill as AccountDetailView for consistency.
struct ConflictDetailView: View {
    let group: ConflictGroup
    var onResolve: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header(title: group.registrableDomain)

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Accounts")
                    UsernamePill(username: group.username, entries: group.entries)
                }

                Button("Mark as Resolved", action: onResolve)
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: 480)
        }
        .navigationTitle(group.registrableDomain)
    }
}

/// Shown in the detail column when an "All Passwords" row is selected — one pill per
/// distinct username under this brand, stacked and scrollable, each styled after Apple's
/// own single-item card (minus the icon — no network access means no real favicons).
struct AccountDetailView: View {
    let group: AccountGroup

    private var pillGroups: [(username: String, entries: [PasswordEntry])] {
        let grouped = Dictionary(grouping: group.entries) { $0.username }
        return grouped
            .map { (username: $0.key, entries: $0.value) }
            .sorted { $0.username.localizedStandardCompare($1.username) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(title: group.displayDomain)

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Accounts")
                    VStack(spacing: 12) {
                        ForEach(pillGroups, id: \.username) { pill in
                            UsernamePill(username: pill.username, entries: pill.entries)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
        }
        .navigationTitle(group.displayDomain)
    }
}

// MARK: - Shared detail-pane header (letter-avatar icon + title, Apple Passwords style)

@ViewBuilder
private func header(title: String) -> some View {
    Text(title)
        .font(.title2.bold())
}

@ViewBuilder
private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
}

// MARK: - Username pill (Apple Passwords card style, minus the icon)

/// One self-contained card for one username: User Name, Password, Website — matching
/// Apple's own single-item card, including its "X and N more" collapse when one username
/// has several URLs with the SAME password. If this username has genuinely different
/// passwords across different URLs, that collapse doesn't happen — see file-level note.
private struct UsernamePill: View {
    let username: String
    let entries: [PasswordEntry]
    @Environment(\.openURL) private var openURL

    private var distinctPasswords: Set<String> {
        Set(entries.filter(\.hasUsablePassword).map(\.password))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldRow(label: "User Name") {
                Text(username).textSelection(.enabled)
            }

            if distinctPasswords.count <= 1 {
                fieldRow(label: "Password") {
                    RevealablePassword(password: entries.first?.password ?? "")
                }
                fieldRow(label: "Website") {
                    websiteValue(entries)
                }
                notesRows(for: entries)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider() }
                    fieldRow(label: "Website") {
                        websiteValue([entry])
                    }
                    fieldRow(label: "Password") {
                        RevealablePassword(password: entry.password)
                    }
                    notesRows(for: [entry])
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
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
            // More than one site under this password — let the person pick which one to
            // open instead of silently always opening the first.
            Menu {
                ForEach(urls, id: \.self) { url in
                    if isOpenable(url) {
                        Button(url.host ?? url.absoluteString) {
                            openURL(url)
                        }
                    } else {
                        Text(url.host ?? url.absoluteString)
                    }
                }
            } label: {
                Text("\(urls.first?.host ?? urls.first?.absoluteString ?? "—") and \(urls.count - 1) more")
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

    /// Only http/https — a crafted CSV row shouldn't be able to smuggle another URL
    /// scheme through this button.
    private func isOpenable(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        return scheme == "http" || scheme == "https"
    }

    /// One row per entry that actually has a note, right under that entry's own
    /// website/password — no site or username label needed, since being inside this
    /// pill already establishes whose account it is.
    @ViewBuilder
    private func notesRows(for entries: [PasswordEntry]) -> some View {
        ForEach(entries.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { entry in
            fieldRow(label: "Notes") {
                Text(entry.notes).textSelection(.enabled)
            }
        }
    }
}

/// Reveals only while hovered, copies to clipboard on click — no separate reveal-gate
/// authentication, matching how the real Passwords app behaves once its own window is
/// unlocked. The app-level lock is the only real gate, by design.
private struct RevealablePassword: View {
    let password: String
    @State private var isHovering = false
    @State private var justCopied = false

    var body: some View {
        Text(justCopied ? "Copied" : (isHovering ? password : "••••••••"))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(isHovering || justCopied ? .primary : .secondary)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                copyToClipboard()
            }
            .help("Click to copy")
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(password, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            justCopied = false
        }

        // 30-second expiry — but only clear the clipboard if nothing else has been
        // copied since. changeCount increments on every pasteboard write, including
        // ours just above, so capturing it now and checking it later is how we avoid
        // wiping out something unrelated the person copied in the meantime.
        let changeCountAtCopy = NSPasteboard.general.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if NSPasteboard.general.changeCount == changeCountAtCopy {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
