import Foundation
import CryptoKit
import Observation

/// Where DismissedStore's hash set is saved/loaded. Kept as a protocol so the hashing
/// logic can be tested without touching disk, while production code still gets a real
/// file-backed implementation (see FileDismissedStorePersistence below).
public protocol DismissedStorePersisting {
    func loadHashes() -> Set<String>
    func saveHashes(_ hashes: Set<String>)
}

/// Tracks which conflict groups the user has marked "handled," so they don't keep
/// resurfacing on every re-import. Stores only salted hashes — never the username or
/// domain in the clear — and nothing about the underlying passwords at all.
///
/// @Observable so a dashboard view filtering on isDismissed(group) automatically
/// re-renders the moment dismiss() is called — no manual refresh plumbing needed.
@Observable
public final class DismissedStore {
    private let persistence: DismissedStorePersisting
    private let salt: Data
    private var hashes: Set<String>

    /// `salt` should be a stable, per-install random value — in the real app, pulled from
    /// Keychain (generated once, reused forever). Passing a fixed salt in tests is fine;
    /// what matters for real use is that it doesn't change between launches, or every
    /// previously dismissed hash would silently stop matching.
    public init(persistence: DismissedStorePersisting, salt: Data) {
        self.persistence = persistence
        self.salt = salt
        self.hashes = persistence.loadHashes()
    }

    public func isDismissed(username: String, domain: String) -> Bool {
        hashes.contains(hash(username: username, domain: domain))
    }

    public func dismiss(username: String, domain: String) {
        hashes.insert(hash(username: username, domain: domain))
        persistence.saveHashes(hashes)
    }

    public func clearAll() {
        hashes.removeAll()
        persistence.saveHashes(hashes)
    }

    // MARK: - Hashing

    /// Username and domain are lowercased before hashing — CSV data is inconsistently
    /// cased (URLs especially), and without normalizing, "Meta.com" and "meta.com" would
    /// silently produce different hashes and dismissal wouldn't stick.
    private func hash(username: String, domain: String) -> String {
        let normalized = "\(username.lowercased())|\(domain.lowercased())"
        let digest = SHA256.hash(data: salt + Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Convenience for the actual call sites (ConflictGroup, not raw strings)

public extension DismissedStore {
    func isDismissed(_ group: ConflictGroup) -> Bool {
        isDismissed(username: group.username, domain: group.registrableDomain)
    }

    func dismiss(_ group: ConflictGroup) {
        dismiss(username: group.username, domain: group.registrableDomain)
    }
}

// MARK: - Real persistence (file-backed, testable with a temp directory)

/// Stores the hash set as a JSON array of hex strings at a given file URL. No password
/// data, no plaintext usernames or domains — just hashes, sorted before writing for
/// deterministic file output (easier to diff/debug, not a functional requirement).
public final class FileDismissedStorePersistence: DismissedStorePersisting {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func loadHashes() -> Set<String> {
        guard
            let data = try? Data(contentsOf: fileURL),
            let array = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return Set(array)
    }

    public func saveHashes(_ hashes: Set<String>) {
        guard let data = try? JSONEncoder().encode(hashes.sorted()) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
