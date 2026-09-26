import SwiftUI
import SiftCore

struct ImportView: View {
    /// entries: what got parsed. sourceURLForDeletion: only set on a fresh drop, since
    /// that's the only path where "offer to delete the source file" makes sense — on a
    /// reload, the user already decided to keep that file last time.
    var onImportSucceeded: (_ entries: [PasswordEntry], _ sourceURLForDeletion: URL?) -> Void

    @State private var isTargeted = false
    @State private var errorMessage: String?
    @State private var showReloadButton = false

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

            if showReloadButton {
                Button("Reload last file") {
                    reloadLastFile()
                }
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
        .dropDestination(for: URL.self) { droppedURLs, _ in
            handleDrop(droppedURLs)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .onAppear {
            showReloadButton = LastFileBookmark.hasBookmark
        }
    }

    private func handleDrop(_ urls: [URL]) {
        errorMessage = nil
        guard let url = urls.first else { return }

        guard url.pathExtension.lowercased() == "csv" else {
            errorMessage = "That doesn't look like a CSV file."
            return
        }

        // Bookmark FIRST, synchronously, before any parsing. The sandbox's access grant
        // from this drop is transient — deferring this call risks it having expired by
        // the time we get around to it. A failure here isn't fatal to *this* import (the
        // drop itself still grants us a read), it just means "reload last file" won't
        // work next launch, so it's swallowed rather than blocking the user.
        try? LastFileBookmark.save(url: url)

        importFile(at: url, isFreshDrop: true)
    }

    private func importFile(at url: URL, isFreshDrop: Bool) {
        do {
            // Dropped file URLs are readable directly without an explicit
            // startAccessingSecurityScopedResource() call — the drop operation itself
            // grants transient access. That call only matters for the bookmark-resolved
            // path in LastFileBookmark, which handles it internally.
            let text = try String(contentsOf: url, encoding: .utf8)
            let entries = try CSVImporter.parse(csvText: text)
            onImportSucceeded(entries, isFreshDrop ? url : nil)
            showReloadButton = true
        } catch let error as CSVImportError {
            errorMessage = error.description
        } catch {
            errorMessage = "Couldn't read that file. \(error.localizedDescription)"
        }
    }

    private func reloadLastFile() {
        errorMessage = nil
        do {
            guard let text = try LastFileBookmark.loadLastFileContents() else {
                errorMessage = "That file isn't there anymore — drop a new export instead."
                showReloadButton = false
                return
            }
            let entries = try CSVImporter.parse(csvText: text)
            onImportSucceeded(entries, nil)
        } catch let error as CSVImportError {
            errorMessage = error.description
        } catch {
            errorMessage = "Couldn't reload the last file. \(error.localizedDescription)"
        }
    }
}
