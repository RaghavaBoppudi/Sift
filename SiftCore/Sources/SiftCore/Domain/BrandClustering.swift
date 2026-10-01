import Foundation

/// Groups entries whose domains share a brand: identical label (google.com, google.co.uk),
/// or one label is a prefix of another (meta.com, metacareers.com).
///
/// Prefix matching is a heuristic, and a loose one: it also relates apple.com to
/// applebees.com, and because the relation is transitive, one short label can pull several
/// unrelated domains into a single cluster. Instagram/Facebook (same owner, unrelated names)
/// is a known, accepted miss. Tightening this needs a product decision, not more string logic.
enum BrandClustering {

    private static let minimumPrefixLength = 4

    static func clusters(of entries: [PasswordEntry]) -> [[PasswordEntry]] {
        var entriesByLabel: [String: [PasswordEntry]] = [:]
        for entry in entries {
            guard let domain = entry.registrableDomain else { continue }
            entriesByLabel[DomainResolver.brandLabel(from: domain), default: []].append(entry)
        }

        // In sorted order every label that has label[i] as a prefix sits immediately after
        // it, so prefix relations are found by scanning forward, not by comparing all pairs.
        let labels = entriesByLabel.keys.sorted()
        var parent = Array(labels.indices)

        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }

        for i in labels.indices where isBrandName(labels[i]) {
            var j = i + 1
            while j < labels.count, labels[j].hasPrefix(labels[i]) {
                let rootI = find(i), rootJ = find(j)
                if rootI != rootJ { parent[rootJ] = rootI }
                j += 1
            }
        }

        var clusters: [Int: [PasswordEntry]] = [:]
        for (index, label) in labels.enumerated() {
            clusters[find(index), default: []] += entriesByLabel[label] ?? []
        }
        return Array(clusters.values)
    }

    /// Long enough to avoid coincidental short-prefix matches, and a plain name rather than
    /// an IP address (which contains dots or colons).
    private static func isBrandName(_ label: String) -> Bool {
        label.count >= minimumPrefixLength
            && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
