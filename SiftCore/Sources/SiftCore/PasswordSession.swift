import Foundation
import Observation

/// Holds the imported passwords for the current run — in memory only, never written to
/// disk. There's a single identity now (this Mac's account), so there's nothing left to
/// separate one person's data from another's the way encryption-per-profile used to; Touch
/// ID gates visibility instead. reset() is the only way this ever empties out on its own.
@Observable
public final class PasswordSession {
    public private(set) var entries: [PasswordEntry] = []

    public init() {}

    /// Called after a successful import (fresh drop or reload-last-file).
    public func load(_ entries: [PasswordEntry]) {
        self.entries = entries
    }

    public var hasData: Bool {
        !entries.isEmpty
    }

    /// Wipes everything in memory. Used by the "Reset" action — after this, the app has
    /// nothing until the person imports again.
    public func reset() {
        entries = []
    }
}
