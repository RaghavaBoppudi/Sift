import SwiftUI
import SiftCore

enum DashboardCategory: Hashable {
    case all
    case duplicates
    case reused
}

enum SortOrder: String, CaseIterable, Identifiable {
    case mostUsed = "Most Accounts"
    case alphabetical = "A–Z"
    var id: String { rawValue }
}

/// Runs the grouping and analysis once, up front. The clustering is quadratic-ish in the
/// worst case, so it must not run inside view bodies, which re-evaluate on every keystroke.
/// Search, sort, and dismissal only filter and reorder the cached results.
@MainActor
@Observable
final class DashboardModel {
    var searchText = ""
    var sortOrder: SortOrder = .mostUsed

    let entryCount: Int
    private let accountGroups: [AccountGroup]
    private let analysis: AnalysisResult
    private let dismissedStore: DismissedStore

    init(entries: [PasswordEntry], dismissedStore: DismissedStore) {
        self.entryCount = entries.count
        self.accountGroups = AccountGrouper.group(entries)
        self.analysis = ConflictAnalyzer.analyze(entries)
        self.dismissedStore = dismissedStore
    }

    // MARK: - Counts (unaffected by search)

    var duplicateCount: Int { undismissedConflicts.count }
    var reuseCount: Int { analysis.reuseGroups.count }

    // MARK: - Lists (searched and sorted)

    var accounts: [AccountGroup] {
        sorted(accountGroups.filter { matches($0.entries) }, count: \.websiteCount, name: \.displayDomain)
    }

    var conflicts: [ConflictGroup] {
        sorted(undismissedConflicts.filter { matches($0.entries) }, count: { $0.entries.count }, name: \.registrableDomain)
    }

    var reuse: [ReuseGroup] {
        sorted(analysis.reuseGroups.filter { matches($0.entries) }, count: { $0.entries.count }, name: { $0.domains.first ?? "" })
    }

    // MARK: - Private

    private var undismissedConflicts: [ConflictGroup] {
        analysis.conflictGroups.filter { !dismissedStore.isDismissed($0) }
    }

    /// A group matches if any entry in it does, so a hit shows the whole group.
    private func matches(_ entries: [PasswordEntry]) -> Bool {
        guard !searchText.isEmpty else { return true }
        return entries.contains {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.username.localizedCaseInsensitiveContains(searchText)
                || ($0.registrableDomain?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// Ties always fall back to name, so the order never shuffles between renders.
    private func sorted<T>(_ items: [T], count: (T) -> Int, name: (T) -> String) -> [T] {
        items.sorted { a, b in
            let byName = name(a).localizedStandardCompare(name(b)) == .orderedAscending
            switch sortOrder {
            case .alphabetical: return byName
            case .mostUsed: return count(a) != count(b) ? count(a) > count(b) : byName
            }
        }
    }
}
