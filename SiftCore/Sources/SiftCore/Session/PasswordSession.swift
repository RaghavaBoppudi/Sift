import Foundation
import Observation

/// The imported passwords for this run. In memory only. Locking the app hides them but does
/// not clear them; only `reset()` (or quitting) empties this.
@Observable
public final class PasswordSession {
    public private(set) var entries: [PasswordEntry] = []

    public init() {}

    public var hasData: Bool { !entries.isEmpty }

    public func load(_ entries: [PasswordEntry]) {
        self.entries = entries
    }

    public func reset() {
        entries = []
    }
}
