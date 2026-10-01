import SwiftUI
import SiftCore

/// "All Passwords" detail: one pill per distinct username under the brand.
struct AccountDetailView: View {
    let group: AccountGroup

    private var pills: [(username: String, entries: [PasswordEntry])] {
        Dictionary(grouping: group.entries) { $0.username.lowercased() }
            .values
            .map { (username: $0[0].username, entries: $0) }
            .sorted { $0.username.localizedStandardCompare($1.username) == .orderedAscending }
    }

    var body: some View {
        DetailScaffold(title: group.displayDomain) {
            DetailSection("Accounts") {
                VStack(spacing: 12) {
                    ForEach(pills, id: \.username) { pill in
                        UsernamePill(username: pill.username, entries: pill.entries)
                    }
                }
            }
        }
    }
}
