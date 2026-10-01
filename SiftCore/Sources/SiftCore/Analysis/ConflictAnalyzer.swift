import Foundation

/// Pure functions: parsed entries in, analysis out. No I/O, no UI types.
public enum ConflictAnalyzer {

    public static func analyze(_ entries: [PasswordEntry]) -> AnalysisResult {
        let categorized = entries.filter { $0.registrableDomain != nil }
        return AnalysisResult(
            conflictGroups: conflictGroups(in: categorized),
            reuseGroups: reuseGroups(in: categorized)
        )
    }

    /// Same username, brand-related domains, more than one distinct password.
    private static func conflictGroups(in entries: [PasswordEntry]) -> [ConflictGroup] {
        // Empty usernames can't be grouped meaningfully; usernames match case-insensitively.
        let byUsername = Dictionary(grouping: entries.filter { !$0.username.isEmpty }) {
            $0.username.lowercased()
        }

        return byUsername.values
            .flatMap(BrandClustering.clusters(of:))
            .compactMap { cluster -> ConflictGroup? in
                let group = ConflictGroup(username: cluster[0].username, entries: cluster)
                return group.distinctPasswords.count > 1 ? group : nil
            }
            .sorted { ($0.registrableDomain, $0.username) < ($1.registrableDomain, $1.username) }
    }

    /// One password on more than one unrelated brand. The same password across one brand's
    /// own domains is the "fine" case and is not reuse.
    private static func reuseGroups(in entries: [PasswordEntry]) -> [ReuseGroup] {
        var clusterIndex: [UUID: Int] = [:]
        for (index, cluster) in BrandClustering.clusters(of: entries).enumerated() {
            for entry in cluster { clusterIndex[entry.id] = index }
        }

        let byPassword = Dictionary(grouping: entries.filter(\.hasUsablePassword), by: \.password)
        return byPassword.values
            .filter { Set($0.compactMap { clusterIndex[$0.id] }).count > 1 }
            .map(ReuseGroup.init(entries:))
            .sorted { ($1.entries.count, $0.domains.first ?? "") < ($0.entries.count, $1.domains.first ?? "") }
    }
}
