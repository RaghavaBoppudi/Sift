import Foundation
@testable import SiftCore

/// Builds an entry directly, bypassing CSV parsing, so analysis tests state exactly what
/// they depend on.
func makeEntry(
    _ domain: String?,
    user: String = "me@example.com",
    pass: String = "pw",
    title: String? = nil
) -> PasswordEntry {
    PasswordEntry(
        title: title ?? domain ?? "Untitled",
        url: domain.flatMap { URL(string: "https://\($0)") },
        registrableDomain: domain,
        username: user,
        password: pass
    )
}
