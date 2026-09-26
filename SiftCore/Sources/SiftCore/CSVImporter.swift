import Foundation

public enum CSVImportError: Error, Equatable, CustomStringConvertible {
    case emptyFile
    case missingRequiredColumns(found: [String])
    case unreadableEncoding

    public var description: String {
        switch self {
        case .emptyFile:
            return "The file is empty."
        case .missingRequiredColumns(let found):
            return "This doesn't look like an Apple Passwords export. " +
                "Expected columns URL, Username, Password — found: \(found.joined(separator: ", "))."
        case .unreadableEncoding:
            return "Couldn't read this file as text. Is it actually a CSV?"
        }
    }
}

public enum CSVImporter {

    private static let requiredColumns: Set<String> = ["url", "username", "password"]

    /// Parses raw CSV text into PasswordEntry rows. Throws CSVImportError if the
    /// required columns aren't present — does not throw on individual bad rows;
    /// a row with an unparseable URL just gets registrableDomain = nil and is
    /// left for the caller to route into "uncategorized".
    public static func parse(csvText: String) throws -> [PasswordEntry] {
        guard !csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CSVImportError.emptyFile
        }

        let rows = Self.parseRows(csvText)
        guard let headerRow = rows.first else {
            throw CSVImportError.emptyFile
        }

        let normalizedHeader = headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let columnIndex = Dictionary(uniqueKeysWithValues: normalizedHeader.enumerated().map { ($1, $0) })

        let foundColumns = Set(normalizedHeader)
        guard requiredColumns.isSubset(of: foundColumns) else {
            throw CSVImportError.missingRequiredColumns(found: headerRow)
        }

        // Optional columns — Apple's export has Title and Notes, but we only hard-require
        // the three that matter for analysis. Missing Title just falls back to the URL.
        let titleIndex = columnIndex["title"]
        let urlIndex = columnIndex["url"]!
        let usernameIndex = columnIndex["username"]!
        let passwordIndex = columnIndex["password"]!

        var entries: [PasswordEntry] = []
        entries.reserveCapacity(rows.count - 1)

        for row in rows.dropFirst() {
            // Guard against short/ragged rows rather than crashing on index out of range.
            guard row.count > urlIndex, row.count > usernameIndex, row.count > passwordIndex else {
                continue
            }

            let rawURL = row[urlIndex].trimmingCharacters(in: .whitespaces)
            let username = row[usernameIndex].trimmingCharacters(in: .whitespaces)
            let password = row[passwordIndex]
            let title = titleIndex.flatMap { row.count > $0 ? row[$0] : nil } ?? rawURL

            // Skip rows with no username at all — nothing to group them by.
            guard !username.isEmpty else { continue }

            let url = URL(string: rawURL)
            let domain = url.flatMap { DomainResolver.registrableDomain(from: $0) }

            entries.append(
                PasswordEntry(
                    title: title.isEmpty ? rawURL : title,
                    url: url,
                    registrableDomain: domain,
                    username: username,
                    password: password
                )
            )
        }

        return entries
    }

    // MARK: - RFC4180-ish row parsing

    /// Hand-rolled parser rather than a naive split(separator: ","). Apple's export
    /// quotes fields containing commas or newlines (Notes and Title can both have
    /// either), and a naive split silently corrupts those rows instead of failing loudly.
    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let chars = Array(text)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if insideQuotes {
                if char == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        // Escaped quote inside a quoted field.
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        insideQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    i += 1
                    continue
                }
            } else {
                switch char {
                case "\"":
                    insideQuotes = true
                    i += 1
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                case "\r":
                    // Swallow bare CR; handled together with \n below.
                    i += 1
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                    i += 1
                default:
                    currentField.append(char)
                    i += 1
                }
            }
        }

        // Flush the last field/row if the file doesn't end in a newline.
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { !($0.count == 1 && $0[0].isEmpty) } // drop trailing blank lines
    }
}
