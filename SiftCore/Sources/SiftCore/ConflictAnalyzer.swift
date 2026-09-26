import Foundation

/// Pure function, no I/O, no side effects — takes parsed entries, returns the analysis.
/// Deliberately has no dependency on CSVImporter or any UI type, so it's trivial to unit
/// test against hand-built fixtures without touching the filesystem.
public enum ConflictAnalyzer {

    public static func analyze(_ entries: [PasswordEntry]) -> AnalysisResult {
        var uncategorized: [PasswordEntry] = []
        var categorized: [PasswordEntry] = []

        for entry in entries {
            if entry.registrableDomain == nil {
                uncategorized.append(entry)
            } else {
                categorized.append(entry)
            }
        }

        let conflictGroups = Self.findConflictGroups(in: categorized)
        let reuseGroups = Self.findReuseGroups(in: categorized)

        return AnalysisResult(
            conflictGroups: conflictGroups,
            reuseGroups: reuseGroups,
            uncategorized: uncategorized
        )
    }

    // MARK: - Duplicate-conflict detection (same username + brand-related domain, different passwords)

    private static func findConflictGroups(in entries: [PasswordEntry]) -> [ConflictGroup] {
        var byUsername: [String: [PasswordEntry]] = [:]
        for entry in entries {
            guard entry.registrableDomain != nil else { continue }
            byUsername[entry.username, default: []].append(entry)
        }

        var groups: [ConflictGroup] = []
        for (username, userEntries) in byUsername {
            for cluster in clusterByBrand(userEntries) {
                // Ignore blank passwords when deciding if there's a real conflict —
                // a passkey-only row with no password isn't "a different password".
                let usable = cluster.filter { $0.hasUsablePassword }
                let distinctPasswords = Set(usable.map(\.password))
                guard distinctPasswords.count > 1 else { continue }

                // Display domain: the shortest domain in the cluster — e.g. "meta.com"
                // rather than "metacareers.com" — as the representative/root brand.
                let displayDomain = cluster
                    .compactMap(\.registrableDomain)
                    .min { $0.count < $1.count } ?? ""

                groups.append(ConflictGroup(username: username, registrableDomain: displayDomain, entries: cluster))
            }
        }

        return groups.sorted { $0.registrableDomain < $1.registrableDomain }
    }

    /// Groups entries whose domains are identical, OR "brand-related" — one domain's
    /// label (the part before the public suffix, e.g. "meta" in meta.com) is a prefix of
    /// another's (e.g. "metacareers" in metacareers.com). Union-find, not a simple hash
    /// key, because this relation is transitive: if A relates to B and B relates to C,
    /// A/B/C all belong in one cluster even if A isn't directly a prefix of C.
    ///
    /// Deliberately does NOT catch same-owner domains with unrelated names (instagram.com
    /// vs facebook.com) — that's a known, accepted gap, not a bug. Reliably catching that
    /// needs real brand knowledge, not string matching, and was explicitly ruled out in
    /// favor of this narrower, false-positive-resistant rule.
    private static func clusterByBrand(_ entries: [PasswordEntry]) -> [[PasswordEntry]] {
        var parent = Array(entries.indices)

        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }
        func union(_ a: Int, _ b: Int) {
            let rootA = find(a), rootB = find(b)
            if rootA != rootB { parent[rootB] = rootA }
        }

        let labels: [String?] = entries.map { entry in
            entry.registrableDomain.map(DomainResolver.brandLabel(from:))
        }

        for i in entries.indices {
            guard let labelI = labels[i] else { continue }
            for j in (i + 1)..<entries.count {
                guard let labelJ = labels[j] else { continue }
                if labelI == labelJ || isBrandPrefix(labelI, labelJ) {
                    union(i, j)
                }
            }
        }

        var clusters: [Int: [PasswordEntry]] = [:]
        for i in entries.indices {
            clusters[find(i), default: []].append(entries[i])
        }
        return Array(clusters.values)
    }

    /// Minimum length guard avoids short-label false positives — e.g. a 2-3 character
    /// label matching as a "prefix" of an unrelated longer one by coincidence.
    private static func isBrandPrefix(_ a: String, _ b: String) -> Bool {
        guard a.count >= 4, b.count >= 4 else { return false }
        let shorter = a.count <= b.count ? a : b
        let longer = a.count <= b.count ? b : a
        return longer.hasPrefix(shorter)
    }

    // MARK: - All-accounts grouping (every entry, clustered by brand, username ignored)

    /// Every entry with a domain, clustered by the same brand-relation as conflict
    /// detection — but without first splitting by username. "How many Google accounts do
    /// I have" is answered by this, regardless of whether those accounts share a login or
    /// even a matching password; ConflictGroup only ever answers a narrower question.
    public static func groupByAccount(_ entries: [PasswordEntry]) -> [AccountGroup] {
        let categorized = entries.filter { $0.registrableDomain != nil }

        return clusterByBrand(categorized).map { cluster in
            let displayDomain = cluster
                .compactMap(\.registrableDomain)
                .min { $0.count < $1.count } ?? ""
            return AccountGroup(displayDomain: displayDomain, entries: cluster)
        }
        .sorted { $0.displayDomain < $1.displayDomain }
    }

    // MARK: - Reuse detection (same password across unrelated username/domain pairs)

    private static func findReuseGroups(in entries: [PasswordEntry]) -> [ReuseGroup] {
        let usable = entries.filter { $0.hasUsablePassword }
        var buckets: [String: [PasswordEntry]] = [:]
        for entry in usable {
            buckets[entry.password, default: []].append(entry)
        }

        return buckets
            .filter { $0.value.count > 1 }
            .map { ReuseGroup(password: $0.key, entries: $0.value) }
            .sorted { $0.entries.count > $1.entries.count }
    }
}
