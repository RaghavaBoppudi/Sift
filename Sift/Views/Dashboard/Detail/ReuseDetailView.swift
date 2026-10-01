import SwiftUI
import SiftCore

struct ReuseDetailView: View {
    let group: ReuseGroup

    var body: some View {
        DetailScaffold(title: "Reused Password") {
            DetailSection("Password") {
                RevealablePassword(password: group.password)
            }
            DetailSection("Used On") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(group.accounts) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.registrableDomain ?? entry.title)
                            Text(entry.username.isEmpty ? "—" : entry.username)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
