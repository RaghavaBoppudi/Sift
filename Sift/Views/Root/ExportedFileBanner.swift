import SwiftUI

/// Offered after a fresh import: the export holds every password in plain text. A banner,
/// not a modal dialog, so nothing is presented while the window swaps to the dashboard.
struct ExportedFileBanner: View {
    let file: URL
    var onTrash: () -> Void
    var onKeep: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Delete the exported CSV?")
                    .font(.headline)
                Text("\(file.lastPathComponent) contains every password in plain text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button("Keep File", action: onKeep)
            Button("Move to Trash", action: onTrash)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .padding()
    }
}
