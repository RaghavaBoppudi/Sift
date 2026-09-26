import Foundation

/// One row from the Apple Passwords CSV export.
public struct PasswordEntry: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public let title: String
    public let url: URL?
    public let registrableDomain: String?
    public let username: String
    public let password: String

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL?,
        registrableDomain: String?,
        username: String,
        password: String
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.registrableDomain = registrableDomain
        self.username = username
        self.password = password
    }

    /// True for rows Apple exports with no real password (passkey-only rows, notes-only rows).
    /// These should never count toward a conflict — an empty password isn't "different."
    public var hasUsablePassword: Bool {
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Same username + same registrable domain, but not all entries share one password.
public struct ConflictGroup: Identifiable {
    public let id: UUID
    public let username: String
    public let registrableDomain: String
    public let entries: [PasswordEntry]

    public init(username: String, registrableDomain: String, entries: [PasswordEntry]) {
        // Deterministic, not random — this group gets reconstructed from scratch on
        // every access of a computed property upstream (DashboardView's currentConflictGroups
        // recomputes it, doesn't cache it), so a fresh UUID() here would mean the same
        // logical group gets a different identity every time, breaking selection.
        self.id = Self.stableID(for: entries)
        self.username = username
        self.registrableDomain = registrableDomain
        self.entries = entries
    }

    private static func stableID(for entries: [PasswordEntry]) -> UUID {
        let smallest = entries.map(\.id.uuidString).min() ?? UUID().uuidString
        return UUID(uuidString: smallest) ?? UUID()
    }

    public var distinctPasswords: Set<String> {
        Set(entries.map(\.password))
    }

    /// Only meaningful if this group was produced by ConflictAnalyzer, which already
    /// filters to groups where this is true — exposed here so views/tests can assert it.
    public var isConflicting: Bool {
        distinctPasswords.count > 1
    }
}

/// Same password reused across entries, regardless of username or domain.
public struct ReuseGroup: Identifiable {
    public let id: UUID
    public let password: String
    public let entries: [PasswordEntry]

    public init(password: String, entries: [PasswordEntry]) {
        self.id = UUID()
        self.password = password
        self.entries = entries
    }
}

/// All entries clustered by brand (same domain, or brand-prefix related — e.g. meta.com
/// and metacareers.com), regardless of username. Unlike ConflictGroup, this isn't about
/// flagging a problem — it's every account under one brand, whether or not the passwords
/// or usernames differ. "How many Google accounts do I have" is this, not ConflictGroup.
public struct AccountGroup: Identifiable {
    public let id: UUID
    /// The shortest domain among the cluster's entries — e.g. "meta.com" rather than
    /// "metacareers.com" — used as the representative name for the group.
    public let displayDomain: String
    public let entries: [PasswordEntry]

    public init(displayDomain: String, entries: [PasswordEntry]) {
        self.id = Self.stableID(for: entries)
        self.displayDomain = displayDomain
        self.entries = entries
    }

    private static func stableID(for entries: [PasswordEntry]) -> UUID {
        let smallest = entries.map(\.id.uuidString).min() ?? UUID().uuidString
        return UUID(uuidString: smallest) ?? UUID()
    }

    /// Row count — each row is one saved URL, which is what "how many websites" means in
    /// practice (two rows for the same literal domain still count as two here).
    public var websiteCount: Int {
        entries.count
    }

    public var distinctUsernameCount: Int {
        Set(entries.map { $0.username.lowercased() }).count
    }

    public var distinctPasswordCount: Int {
        Set(entries.filter(\.hasUsablePassword).map(\.password)).count
    }
}

/// The full output of a run: what got flagged, and what fell through the cracks.
public struct AnalysisResult {
    public let conflictGroups: [ConflictGroup]
    public let reuseGroups: [ReuseGroup]
    /// Rows with no parseable URL/domain — shown separately so nothing silently disappears.
    public let uncategorized: [PasswordEntry]

    public init(conflictGroups: [ConflictGroup], reuseGroups: [ReuseGroup], uncategorized: [PasswordEntry]) {
        self.conflictGroups = conflictGroups
        self.reuseGroups = reuseGroups
        self.uncategorized = uncategorized
    }
}
