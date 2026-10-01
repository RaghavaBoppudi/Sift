import Foundation

enum LastFileBookmarkError: Error, CustomStringConvertible {
    case bookmarkCreationFailed
    case resolutionFailed
    case accessDenied

    var description: String {
        switch self {
        case .bookmarkCreationFailed: return "Couldn't remember that file's location."
        case .resolutionFailed: return "Couldn't locate the last file. Drop a new export instead."
        case .accessDenied: return "Sift no longer has access to the last file. Drop a new export instead."
        }
    }
}

/// Remembers where the last CSV was, never its contents: a security-scoped bookmark only.
/// One global bookmark (single identity).
enum LastFileBookmark {
    private static let defaultsKey = "lastFileBookmark"

    static var hasBookmark: Bool {
        UserDefaults.standard.data(forKey: defaultsKey) != nil
    }

    /// Must run while the drop's temporary sandbox access is still live, i.e. synchronously
    /// inside the drop handler.
    static func save(url: URL) throws {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            throw LastFileBookmarkError.bookmarkCreationFailed
        }
    }

    /// nil (not an error) when there's no bookmark or the file is gone.
    static func loadLastFileContents() throws -> String? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }

        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            throw LastFileBookmarkError.resolutionFailed
        }

        guard url.startAccessingSecurityScopedResource() else { throw LastFileBookmarkError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        // Refreshing a stale bookmark needs access to be active, so it happens after the guard.
        if isStale { try? save(url: url) }

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
