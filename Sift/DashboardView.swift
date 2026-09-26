import SwiftUI
import SiftCore

private enum DashboardCategory: Hashable {
    case all
    case duplicates
}

private enum SortOrder: String, CaseIterable, Identifiable {
    case mostUsed = "Most Accounts"
    case alphabetical = "A–Z"
    var id: String { rawValue }
}

struct DashboardView: View {
    let session: PasswordSession
    let dismissedStore: DismissedStore
    let appGate: AuthGate
    var onReset: () -> Void

    @State private var analysis: AnalysisResult?
    // Defaults to .all, matching Apple's own Passwords app, which always has a category
    // selected on launch — there's no real "pick something first" empty state anymore.
    @State private var selectedCategory: DashboardCategory? = .all
    @State private var selectedGroupID: UUID?
    @State private var showResetConfirmation = false
    @State private var cachedAccountImage: NSImage?
    @State private var sortOrder: SortOrder = .mostUsed
    @State private var searchText = ""

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            middleList
        } detail: {
            detailPane
        }
        // .balanced keeps all three columns visible at a sane proportion, rather than
        // .automatic's default behavior of collapsing the least-recently-used column
        // when space is tight — which is very likely why the detail pane wasn't opening.
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
                            sortOrder = order
                        } label: {
                            Label {
                                Text(order.rawValue)
                            } icon: {
                                Image(systemName: "checkmark")
                                    .opacity(sortOrder == order ? 1 : 0)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
                .help("Sort")
            }
            // Liquid Glass gives every toolbar item a shared glass background by
            // default — opting this non-interactive avatar out of it entirely, per
            // Apple's own guidance, keeps it plain and keeps it from fusing with Lock.
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if let cachedAccountImage {
                        Image(nsImage: cachedAccountImage)
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
        .confirmationDialog(
            "Reset Sift?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: onReset)
        } message: {
            Text("This clears everything imported this session and your dismissed history. You'll need to import your CSV again.")
        }
        .task {
            analysis = ConflictAnalyzer.analyze(session.entries)
            cachedAccountImage = LocalIdentity.accountImage()
        }
        .onChange(of: selectedCategory) { _, _ in
            selectedGroupID = nil
        }
        // Keeps something selected whenever possible, matching Apple's own list, which
        // never shows an empty detail pane while rows exist.
        .onChange(of: currentAccountGroups.map(\.id)) { _, ids in
            if selectedCategory == .all, selectedGroupID == nil {
                selectedGroupID = ids.first
            }
        }
        .onChange(of: currentConflictGroups.map(\.id)) { _, ids in
            if selectedCategory == .duplicates, selectedGroupID == nil {
                selectedGroupID = ids.first
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            Label("All Passwords", systemImage: "key")
                .badge(session.entries.count)
                .tag(DashboardCategory.all)

            if let analysis {
                let visibleConflicts = analysis.conflictGroups.filter { !dismissedStore.isDismissed($0) }
                Label("Duplicate Passwords", systemImage: "exclamationmark.triangle")
                    .badge(visibleConflicts.count)
                    .tag(DashboardCategory.duplicates)
            }
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

    // MARK: - Middle list (rows within the selected category)

    @ViewBuilder
    private var middleList: some View {
        switch selectedCategory {
        case .none:
            ContentUnavailableView("Select a Category", systemImage: "sidebar.left")

        case .all:
            let groups = currentAccountGroups
            if groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(groups, selection: $selectedGroupID) { group in
                    row(title: group.displayDomain, subtitle: accountSubtitle(for: group))
                        .tag(group.id)
                }
                .navigationTitle("All Passwords")
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search by title, site, or username")
            }

        case .duplicates:
            let groups = currentConflictGroups
            if groups.isEmpty {
                ContentUnavailableView(
                    "All Clear",
                    systemImage: "checkmark.seal",
                    description: Text("No duplicate passwords found.")
                )
            } else {
                List(groups, selection: $selectedGroupID) { group in
                    row(
                        title: group.registrableDomain,
                        subtitle: "\(group.entries.count) accounts, \(group.distinctPasswords.count) passwords found"
                    )
                    .tag(group.id)
                }
                .navigationTitle("Duplicate Passwords")
            }
        }
    }

    private func row(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail pane (selected row's full breakdown)

    @ViewBuilder
    private var detailPane: some View {
        switch selectedCategory {
        case .none:
            emptyDetailState

        case .all:
            if let group = currentAccountGroups.first(where: { $0.id == selectedGroupID }) {
                AccountDetailView(group: group)
            } else {
                emptyDetailState
            }

        case .duplicates:
            if let group = currentConflictGroups.first(where: { $0.id == selectedGroupID }) {
                ConflictDetailView(group: group) {
                    dismissedStore.dismiss(group)
                    selectedGroupID = nil
                }
            } else {
                emptyDetailState
            }
        }
    }

    private var emptyDetailState: some View {
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

    // MARK: - Data (computed fresh from state — cheap at this data scale)

    private var currentAccountGroups: [AccountGroup] {
        sortedAccounts(ConflictAnalyzer.groupByAccount(searchFiltered(session.entries)))
    }

    private var currentConflictGroups: [ConflictGroup] {
        guard let analysis else { return [] }
        return sortedConflicts(analysis.conflictGroups.filter { !dismissedStore.isDismissed($0) })
    }

    // MARK: - Sorting & filtering

    private func searchFiltered(_ entries: [PasswordEntry]) -> [PasswordEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText)
                || entry.username.localizedCaseInsensitiveContains(searchText)
                || (entry.registrableDomain?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func accountSubtitle(for group: AccountGroup) -> String {
        func pluralize(_ count: Int, _ noun: String) -> String {
            "\(count) \(noun)\(count == 1 ? "" : "s")"
        }
        return "\(pluralize(group.websiteCount, "website")), "
            + "\(pluralize(group.distinctUsernameCount, "username")), "
            + pluralize(group.distinctPasswordCount, "password")
    }

    private func sortedAccounts(_ groups: [AccountGroup]) -> [AccountGroup] {
        switch sortOrder {
        case .alphabetical:
            return groups.sorted {
                $0.displayDomain.localizedStandardCompare($1.displayDomain) == .orderedAscending
            }
        case .mostUsed:
            return groups.sorted { $0.websiteCount > $1.websiteCount }
        }
    }

    private func sortedConflicts(_ groups: [ConflictGroup]) -> [ConflictGroup] {
        switch sortOrder {
        case .alphabetical:
            return groups.sorted {
                $0.registrableDomain.localizedStandardCompare($1.registrableDomain) == .orderedAscending
            }
        case .mostUsed:
            return groups.sorted { $0.entries.count > $1.entries.count }
        }
    }
}
