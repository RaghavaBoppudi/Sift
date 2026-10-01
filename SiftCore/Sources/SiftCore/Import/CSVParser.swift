import Foundation

/// RFC 4180 row parser. Not a split on commas: Apple quotes Title and Notes fields that
/// contain commas, quotes, or newlines, and a naive split corrupts those rows silently.
///
/// Iterates unicode scalars, not Characters: Swift fuses "\r\n" into one Character, which
/// would never match a "\n" or "\r" case and collapse a CRLF file into a single row.
enum CSVParser {
    static func rows(from text: String) -> [[String]] {
        let scalars = Array(text.unicodeScalars)
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var insideQuotes = false
        var i = 0

        while i < scalars.count {
            let scalar = scalars[i]
            if insideQuotes {
                if scalar == "\"" {
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else {
                switch scalar {
                case "\"":
                    insideQuotes = true
                case ",":
                    row.append(String(field))
                    field = String.UnicodeScalarView()
                case "\n", "\r":
                    if scalar == "\r", i + 1 < scalars.count, scalars[i + 1] == "\n" { i += 1 }
                    row.append(String(field))
                    rows.append(row)
                    row = []
                    field = String.UnicodeScalarView()
                default:
                    field.append(scalar)
                }
            }
            i += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }

        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
