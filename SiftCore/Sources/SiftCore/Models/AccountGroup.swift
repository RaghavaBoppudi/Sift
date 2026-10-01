import Foundation

/// Every saved entry under one brand, whether or not usernames or passwords match.
/// Answers "how many Google accounts do I have", which ConflictGroup deliberately doesn't.
public struct AccountGroup: Identifiable, Sendable {
    public let id: UUID
    public let displayDomain: String
    public let entries: [PasswordEntry]

    init(displayDomain: String, entries: [PasswordEntry]) {
        self.id = entries.stableGroupID
        self.displayDomain = displayDomain
        self.entries = entries
    }

    /// One saved row is one website, even if two rows share a literal domain.
    public var websiteCount: Int { entries.count }

    public var distinctUsernameCount: Int {
        Set(entries.map { $0.username.lowercased() }).count
    }

    public var distinctPasswordCount: Int {
        Set(entries.filter(\.hasUsablePassword).map(\.password)).count
    }
}
