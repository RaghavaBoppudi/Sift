import Foundation

/// Where the dismissed-hash set is saved. A protocol so the hashing logic is testable
/// without touching disk.
public protocol DismissedStorePersisting {
    func loadHashes() -> Set<String>
    func saveHashes(_ hashes: Set<String>)
}

/// JSON array of hex strings. No passwords, no plaintext usernames or domains.
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
