import Foundation

enum LastFileBookmarkError: Error {
    case bookmarkCreationFailed
    case resolutionFailed
    case accessDenied
}

/// Remembers where the last-imported CSV was, without ever storing the file's contents —
/// just a security-scoped bookmark to its location. One global bookmark now (single
/// identity, no profiles to key by).
enum LastFileBookmark {

    private static let defaultsKey = "lastFileBookmark"

    /// Call this immediately when the user drops or picks a file — the sandbox grants
    /// temporary access at that moment, and the bookmark must be created while that
    /// access is still live. Don't defer this call.
    static func save(url: URL) throws {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: defaultsKey)
        } catch {
            throw LastFileBookmarkError.bookmarkCreationFailed
        }
    }

    static var hasBookmark: Bool {
        UserDefaults.standard.data(forKey: defaultsKey) != nil
    }

    /// Resolves the bookmark and hands back the file's contents as text, already wrapped
    /// with start/stop security-scoped access. Returns nil (not throws) if there's simply
    /// no bookmark saved, or if the file's gone — both are the ordinary "nothing to
    /// reload" case, not a failure.
    static func loadLastFileContents() throws -> String? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }

        var isStale = false
        let resolvedURL: URL
        do {
            resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw LastFileBookmarkError.resolutionFailed
        }

        if isStale {
            try? save(url: resolvedURL)
        }

        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw LastFileBookmarkError.accessDenied
        }
        defer { resolvedURL.stopAccessingSecurityScopedResource() }

        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            return nil
        }

        return try String(contentsOf: resolvedURL, encoding: .utf8)
    }

    /// Called on explicit source-file deletion after import, or on Reset.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
