import SwiftUI
import SiftCore

struct ImportView: View {
    /// `droppedFile` is set only for a fresh drop, the only case where offering to delete
    /// the source makes sense. On a reload the person already chose to keep it.
    var onImport: (_ entries: [PasswordEntry], _ droppedFile: URL?) -> Void

    @State private var isTargeted = false
    @State private var errorMessage: String?
    @State private var hasLastFile = LastFileBookmark.hasBookmark

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)

            Text("Drop your Apple Passwords export here")
                .font(.headline)

            ExportMenuHint()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if hasLastFile {
                Button("Reload last file", action: reloadLastFile)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
        )
        .padding()
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(urls)
        } isTargeted: {
            isTargeted = $0
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsButton()
            }
        }
    }

    private func handleDrop(_ urls: [URL]) -> Bool {
        errorMessage = nil
        guard let url = urls.first else { return false }
        guard url.pathExtension.lowercased() == "csv" else {
            errorMessage = "That doesn't look like a CSV file."
            return false
        }

        do {
            let entries = try CSVImporter.parse(csvText: String(contentsOf: url, encoding: .utf8))
            // Bookmark only after a successful parse, but still synchronously in this handler:
            // the drop's sandbox access is transient.
            try? LastFileBookmark.save(url: url)
            onImport(entries, url)
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    private func reloadLastFile() {
        errorMessage = nil
        do {
            guard let text = try LastFileBookmark.loadLastFileContents() else {
                errorMessage = "That file isn't there anymore. Drop a new export instead."
                hasLastFile = false
                return
            }
            onImport(try CSVImporter.parse(csvText: text), nil)
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case let error as CSVImportError: return error.description
        case let error as LastFileBookmarkError: return error.description
        default: return "Couldn't read that file. \(error.localizedDescription)"
        }
    }
}
