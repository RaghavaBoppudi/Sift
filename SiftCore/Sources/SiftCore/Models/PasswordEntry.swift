import Foundation

/// One row from the Apple Passwords CSV export. Deliberately not Codable: nothing in this
/// app should ever be able to serialize a password by accident.
public struct PasswordEntry: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let url: URL?
    public let registrableDomain: String?
    public let username: String
    public let password: String
    public let notes: String

    init(
        id: UUID = UUID(),
        title: String,
        url: URL?,
        registrableDomain: String?,
        username: String,
        password: String,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.registrableDomain = registrableDomain
        self.username = username
        self.password = password
        self.notes = notes
    }

    /// False for rows Apple exports with no real password (passkey-only, notes-only).
    /// An empty password is never "a different password".
    public var hasUsablePassword: Bool {
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Collection where Element == PasswordEntry {
    /// Shortest registrable domain in the collection ("meta.com" over "metacareers.com"),
    /// ties broken alphabetically so the result never depends on input order.
    var representativeDomain: String {
        compactMap(\.registrableDomain).min { ($0.count, $0) < ($1.count, $1) } ?? ""
    }

    /// Groups are rebuilt from scratch whenever the analysis reruns, so identity must be
    /// derived from the members, not randomly generated, or list selection would reset.
    var stableGroupID: UUID {
        map(\.id).min { $0.uuidString < $1.uuidString } ?? UUID()
    }

    /// Sorted, de-duplicated registrable domains.
    var sortedDomains: [String] {
        Set(compactMap(\.registrableDomain)).sorted()
    }
}
