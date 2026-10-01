import Foundation

public enum CSVImportError: Error, Equatable, CustomStringConvertible {
    case emptyFile
    case missingRequiredColumns(found: [String])
    case noUsableRows

    public var description: String {
        switch self {
        case .emptyFile:
            return "The file is empty."
        case .missingRequiredColumns(let found):
            return "This doesn't look like an Apple Passwords export. "
                + "Expected columns URL, Username, Password — found: \(found.joined(separator: ", "))."
        case .noUsableRows:
            return "The file has the right columns but no usable rows."
        }
    }
}

public enum CSVImporter {

    /// Throws only for file-level problems. A row with an unparseable URL still imports,
    /// with a nil domain; a ragged row (too few columns) is skipped.
    public static func parse(csvText: String) throws -> [PasswordEntry] {
        var rows = CSVParser.rows(from: withoutBOM(csvText))
        guard !rows.isEmpty else { throw CSVImportError.emptyFile }

        let headerRow = rows.removeFirst()
        let header = headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        // First occurrence wins; a repeated header must not crash the app.
        let columns = Dictionary(
            header.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        guard let urlIndex = columns["url"],
              let usernameIndex = columns["username"],
              let passwordIndex = columns["password"]
        else {
            throw CSVImportError.missingRequiredColumns(found: headerRow)
        }
        let titleIndex = columns["title"]
        let notesIndex = columns["notes"]
        let requiredWidth = max(urlIndex, usernameIndex, passwordIndex) + 1

        let entries: [PasswordEntry] = rows.compactMap { row in
            guard row.count >= requiredWidth else { return nil }

            let rawURL = row[urlIndex].trimmingCharacters(in: .whitespaces)
            let title = titleIndex.flatMap { row.count > $0 ? row[$0] : nil } ?? ""
            let url = URL(string: rawURL)

            return PasswordEntry(
                title: title.isEmpty ? rawURL : title,
                url: url,
                registrableDomain: url.flatMap(DomainResolver.registrableDomain(from:)),
                username: row[usernameIndex].trimmingCharacters(in: .whitespaces),
                password: row[passwordIndex],
                notes: notesIndex.flatMap { row.count > $0 ? row[$0] : nil } ?? ""
            )
        }

        guard !entries.isEmpty else { throw CSVImportError.noUsableRows }
        return entries
    }

    /// A UTF-8 BOM (Excel re-saves add one) would otherwise stick to the first header and
    /// make "Title" unrecognizable.
    private static func withoutBOM(_ text: String) -> String {
        var text = text
        if text.unicodeScalars.first == "\u{FEFF}" {
            text.unicodeScalars.removeFirst()
        }
        return text
    }
}
