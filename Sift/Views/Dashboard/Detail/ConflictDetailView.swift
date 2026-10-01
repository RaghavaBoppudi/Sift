import SwiftUI
import SiftCore

/// "Duplicate Passwords" detail. A conflict group is one username by construction, so
/// there is always exactly one pill.
struct ConflictDetailView: View {
    let group: ConflictGroup
    var onResolve: () -> Void

    var body: some View {
        DetailScaffold(title: group.registrableDomain) {
            DetailSection("Accounts") {
                UsernamePill(username: group.username, entries: group.entries)
            }
            Button("Mark as Resolved", action: onResolve)
                .buttonStyle(.borderedProminent)
        }
    }
}
