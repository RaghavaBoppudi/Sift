import Foundation

/// Same username (case-insensitive) across brand-related domains, with more than one
/// distinct password saved.
public struct ConflictGroup: Identifiable, Sendable {
    public let id: UUID
    public let username: String
    public let registrableDomain: String
    public let entries: [PasswordEntry]
    /// What dismissal is keyed on, together with the username.
    public let domains: [String]

    init(username: String, entries: [PasswordEntry]) {
        self.id = entries.stableGroupID
        self.username = username
        self.registrableDomain = entries.representativeDomain
        self.entries = entries
        self.domains = entries.sortedDomains
    }

    public var distinctPasswords: Set<String> {
        Set(entries.filter(\.hasUsablePassword).map(\.password))
    }
}
