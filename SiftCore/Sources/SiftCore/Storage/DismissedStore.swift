import Foundation
import CryptoKit
import Observation

/// Remembers which conflict groups the user marked resolved so they don't resurface on
/// every import. Keyed on username + the group's set of domains, never on passwords: a
/// dismissed group stays dismissed even if its passwords change later. That is a
/// deliberate tradeoff; it also keeps password-derived data off disk.
///
/// `salt` must be stable across launches, or every stored hash silently stops matching.
@Observable
public final class DismissedStore {
    private let persistence: DismissedStorePersisting
    private let salt: Data
    private var hashes: Set<String>

    public init(persistence: DismissedStorePersisting, salt: Data) {
        self.persistence = persistence
        self.salt = salt
        self.hashes = persistence.loadHashes()
    }

    public func isDismissed(_ group: ConflictGroup) -> Bool {
        hashes.contains(hash(for: group))
    }

    public func dismiss(_ group: ConflictGroup) {
        hashes.insert(hash(for: group))
        persistence.saveHashes(hashes)
    }

    public func clearAll() {
        hashes.removeAll()
        persistence.saveHashes(hashes)
    }

    private func hash(for group: ConflictGroup) -> String {
        let key = ([group.username.lowercased()] + group.domains).joined(separator: "|")
        let digest = SHA256.hash(data: salt + Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
