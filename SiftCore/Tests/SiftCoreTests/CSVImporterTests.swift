import XCTest
@testable import SiftCore

final class CSVImporterTests: XCTestCase {

    private let header = "Title,URL,Username,Password,Notes"

    func testParsesAStandardRow() throws {
        let csv = header + "\nMeta,https://accounts.meta.com/login,me@example.com,pw1,some note"
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Meta")
        XCTAssertEqual(entries[0].registrableDomain, "meta.com")
        XCTAssertEqual(entries[0].username, "me@example.com")
        XCTAssertEqual(entries[0].password, "pw1")
        XCTAssertEqual(entries[0].notes, "some note")
    }

    func testRejectsFileWithoutRequiredColumns() {
        XCTAssertThrowsError(try CSVImporter.parse(csvText: "Name,Website,Notes\nfoo,bar,baz")) { error in
            guard case CSVImportError.missingRequiredColumns = error else {
                return XCTFail("Expected missingRequiredColumns, got \(error)")
            }
        }
    }

    func testRejectsEmptyFile() {
        XCTAssertThrowsError(try CSVImporter.parse(csvText: "")) {
            XCTAssertEqual($0 as? CSVImportError, .emptyFile)
        }
        XCTAssertThrowsError(try CSVImporter.parse(csvText: "\n\n")) {
            XCTAssertEqual($0 as? CSVImportError, .emptyFile)
        }
    }

    func testRejectsHeaderOnlyFile() {
        XCTAssertThrowsError(try CSVImporter.parse(csvText: header + "\n")) {
            XCTAssertEqual($0 as? CSVImportError, .noUsableRows)
        }
    }

    func testQuotedFieldsWithCommasAndEscapedQuotes() throws {
        let csv = header + "\n\"Note, with comma\",https://a.com,u1,p1,\"said \"\"hi\"\" there\""
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Note, with comma")
        XCTAssertEqual(entries[0].notes, "said \"hi\" there")
    }

    func testQuotedFieldWithEmbeddedNewline() throws {
        let csv = header + "\nA,https://a.com,u1,p1,\"line one\nline two\"\nB,https://b.com,u2,p2,"
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].notes, "line one\nline two")
    }

    func testCRLFLineEndings() throws {
        let csv = header + "\r\nA,https://a.com,u1,p1,\r\nB,https://b.com,u2,p2,\r\n"
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.map(\.title), ["A", "B"])
    }

    func testLeadingByteOrderMarkDoesNotBreakTheFirstHeader() throws {
        let csv = "\u{FEFF}" + header + "\nA,https://a.com,u1,p1,"
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.first?.title, "A")
    }

    func testDuplicateHeaderDoesNotCrashAndFirstColumnWins() throws {
        let csv = "Title,URL,Username,Password,Password\nA,https://a.com,u1,first,second"
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.first?.password, "first")
    }

    func testRaggedRowsAreSkipped() throws {
        let csv = header + "\nA,https://a.com\nB,https://b.com,u2,p2,"
        let entries = try CSVImporter.parse(csvText: csv)

        XCTAssertEqual(entries.map(\.title), ["B"])
    }

    func testRowsWithNoUsernameAreKept() throws {
        let entries = try CSVImporter.parse(csvText: header + "\nA,https://a.com,,p1,")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].username, "")
    }

    func testUnparseableURLStillImportsWithNoDomain() throws {
        let entries = try CSVImporter.parse(csvText: header + "\nBroken,not a url,u1,p1,")

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].registrableDomain)
    }

    func testMissingTitleColumnFallsBackToURL() throws {
        let entries = try CSVImporter.parse(csvText: "URL,Username,Password\nhttps://a.com,u1,p1")

        XCTAssertEqual(entries.first?.title, "https://a.com")
        XCTAssertEqual(entries.first?.notes, "")
    }
}
