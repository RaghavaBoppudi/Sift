import SwiftUI
import SiftCore

struct DashboardView: View {
    let appGate: AuthGate
    let dismissedStore: DismissedStore
    var onReset: () -> Void

    @State private var model: DashboardModel
    // Defaults to .all, like Apple's Passwords app, which always has a category selected.
    @State private var category: DashboardCategory? = .all
    @State private var selectedID: UUID?
    @State private var showResetConfirmation = false
    @State private var accountImage: NSImage?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(entries: [PasswordEntry], dismissedStore: DismissedStore, appGate: AuthGate, onReset: @escaping () -> Void) {
        self.appGate = appGate
        self.dismissedStore = dismissedStore
        self.onReset = onReset
        _model = State(initialValue: DashboardModel(entries: entries, dismissedStore: dismissedStore))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            middleList
                .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search by title, site, or username")
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appGate.lockNow()
                } label: {
                    Image(systemName: "lock.fill")
                }
                .help("Lock Sift")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            model.sortOrder = order
                        } label: {
                            Label {
                                Text(order.rawValue)
                            } icon: {
                                Image(systemName: "checkmark").opacity(model.sortOrder == order ? 1 : 0)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
                .help("Sort")
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsButton()
            }
            // Non-interactive avatar: opted out of Liquid Glass's shared toolbar background
            // so it doesn't fuse with the Lock button.
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if let accountImage {
                        Image(nsImage: accountImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 26, height: 26)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .confirmationDialog("Reset Sift?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: onReset)
        } message: {
            Text("This clears everything imported this session and your dismissed history. You'll need to import your CSV again.")
        }
        .task {
            let data = await Task.detached(priority: .utility) { LocalIdentity.accountImageData() }.value
            accountImage = data.flatMap(NSImage.init(data:))
        }
        .onAppear { selectedID = currentIDs.first }
        .onChange(of: category) { selectedID = currentIDs.first }
        // Keeps something selected whenever rows exist (search, sort, or dismissal can
        // remove the selected row), matching Apple's list, which never shows an empty
        // detail pane while rows exist.
        .onChange(of: currentIDs) { _, ids in
            if selectedID.map({ !ids.contains($0) }) ?? true {
                selectedID = ids.first
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $category) {
            Label("All Passwords", systemImage: "key")
                .badge(model.entryCount)
                .tag(DashboardCategory.all)
            Label("Duplicate Passwords", systemImage: "exclamationmark.triangle")
                .badge(model.duplicateCount)
                .tag(DashboardCategory.duplicates)
            Label("Reused Passwords", systemImage: "arrow.triangle.2.circlepath")
                .badge(model.reuseCount)
                .tag(DashboardCategory.reused)
        }
        .navigationTitle("Sift")
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Middle list

    @ViewBuilder
    private var middleList: some View {
        switch category {
        case .none:
            ContentUnavailableView("Select a Category", systemImage: "sidebar.left")

        case .all:
            let groups = model.accounts
            if groups.isEmpty {
                emptyList(title: "No Passwords", description: "Nothing to show.")
            } else {
                List(groups, selection: $selectedID) { group in
                    row(title: group.displayDomain, subtitle: accountSubtitle(for: group)).tag(group.id)
                }
                .navigationTitle("All Passwords")
            }

        case .duplicates:
            let groups = model.conflicts
            if groups.isEmpty {
                emptyList(title: "All Clear", description: "No duplicate passwords found.")
            } else {
                List(groups, selection: $selectedID) { group in
                    row(
                        title: group.registrableDomain,
                        subtitle: "\(group.entries.count) accounts, \(group.distinctPasswords.count) passwords found"
                    )
                    .tag(group.id)
                }
                .navigationTitle("Duplicate Passwords")
            }

        case .reused:
            let groups = model.reuse
            if groups.isEmpty {
                emptyList(title: "All Clear", description: "No password is used on more than one site.")
            } else {
                List(groups, selection: $selectedID) { group in
                    row(title: reuseTitle(for: group), subtitle: "Used on \(group.accounts.count) accounts").tag(group.id)
                }
                .navigationTitle("Reused Passwords")
            }
        }
    }

    /// Keeps the search field alive: it's attached to the column, not to a list that
    /// disappears when a search matches nothing.
    @ViewBuilder
    private func emptyList(title: String, description: String) -> some View {
        if model.searchText.isEmpty {
            ContentUnavailableView(title, systemImage: "checkmark.seal", description: Text(description))
        } else {
            ContentUnavailableView.search(text: model.searchText)
        }
    }

    private func row(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        switch category {
        case .all:
            if let group = model.accounts.first(where: { $0.id == selectedID }) {
                AccountDetailView(group: group)
            } else {
                emptyDetail
            }
        case .duplicates:
            if let group = model.conflicts.first(where: { $0.id == selectedID }) {
                ConflictDetailView(group: group) { dismissedStore.dismiss(group) }
            } else {
                emptyDetail
            }
        case .reused:
            if let group = model.reuse.first(where: { $0.id == selectedID }) {
                ReuseDetailView(group: group)
            } else {
                emptyDetail
            }
        case .none:
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
            Text("Select an item to see its details")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var currentIDs: [UUID] {
        switch category {
        case .all: return model.accounts.map(\.id)
        case .duplicates: return model.conflicts.map(\.id)
        case .reused: return model.reuse.map(\.id)
        case .none: return []
        }
    }

    private func accountSubtitle(for group: AccountGroup) -> String {
        func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
        return [
            count(group.websiteCount, "website"),
            count(group.distinctUsernameCount, "username"),
            count(group.distinctPasswordCount, "password")
        ].joined(separator: ", ")
    }

    private func reuseTitle(for group: ReuseGroup) -> String {
        let shown = group.domains.prefix(2).joined(separator: ", ")
        let extra = group.domains.count - 2
        return extra > 0 ? "\(shown) +\(extra)" : shown
    }
}
