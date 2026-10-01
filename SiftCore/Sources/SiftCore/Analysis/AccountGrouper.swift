import Foundation

public enum AccountGrouper {

    /// Every entry lands in exactly one group. Entries with no parseable domain become
    /// standalone groups named by title, so nothing disappears from the list.
    public static func group(_ entries: [PasswordEntry]) -> [AccountGroup] {
        let categorized = entries.filter { $0.registrableDomain != nil }
        let uncategorized = entries.filter { $0.registrableDomain == nil }

        let branded = BrandClustering.clusters(of: categorized).map {
            AccountGroup(displayDomain: $0.representativeDomain, entries: $0)
        }
        let standalone = uncategorized.map {
            AccountGroup(displayDomain: $0.title.isEmpty ? "Untitled" : $0.title, entries: [$0])
        }
        return branded + standalone
    }
}
