import Foundation

/// One password used on more than one unrelated brand.
public struct ReuseGroup: Identifiable, Sendable {
    public let id: UUID
    public let password: String
    /// Every saved row using the password.
    public let entries: [PasswordEntry]
    /// One row per distinct site + username. Repeat saves of the same login (or several
    /// subdomains of one site) collapse, so the list never shows the same line twice.
    public let accounts: [PasswordEntry]
    public let domains: [String]

    init(entries: [PasswordEntry]) {
        self.id = entries.stableGroupID
        self.password = entries[0].password
        self.entries = entries
        self.domains = entries.sortedDomains

        var seen = Set<String>()
        self.accounts = entries.filter { entry in
            let site = (entry.registrableDomain ?? entry.title).lowercased()
            return seen.insert("\(site)|\(entry.username.lowercased())").inserted
        }
    }
}
