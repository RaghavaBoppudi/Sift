import XCTest
@testable import SiftCore

final class SiftCoreTests: XCTestCase {

    private func loadFixture() throws -> [PasswordEntry] {
        let url = Bundle.module.url(forResource: "sample", withExtension: "csv", subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        return try CSVImporter.parse(csvText: text)
    }

    // MARK: - CSVImporter

    func testRejectsFileWithoutRequiredColumns() {
        let badCSV = "Name,Website,Notes\nfoo,bar,baz"
        XCTAssertThrowsError(try CSVImporter.parse(csvText: badCSV)) { error in
            guard case CSVImportError.missingRequiredColumns = error else {
                XCTFail("Expected missingRequiredColumns, got \(error)")
                return
            }
        }
    }

    func testRejectsEmptyFile() {
        XCTAssertThrowsError(try CSVImporter.parse(csvText: "")) { error in
            XCTAssertEqual(error as? CSVImportError, .emptyFile)
        }
    }

    func testParsesQuotedFieldsWithEmbeddedCommas() throws {
        let entries = try loadFixture()
        // Row 8 has a Notes field with an embedded comma inside quotes — if the parser
        // naively split on "," this row (and everything after it) would be corrupted.
        XCTAssertTrue(entries.contains { $0.title == "Note-only, comma test" })
    }

    func testTotalRowCount() throws {
        let entries = try loadFixture()
        XCTAssertEqual(entries.count, 9)
    }

    // MARK: - DomainResolver

    func testSimpleDomainCollapsesSubdomain() {
        let url = URL(string: "https://accounts.meta.com/login")!
        XCTAssertEqual(DomainResolver.registrableDomain(from: url), "meta.com")
    }

    func testKnownTwoLabelSuffixDoesNotCollapseUnrelatedSites() {
        let bbc = URL(string: "https://bbc.co.uk/account")!
        let bank = URL(string: "https://bank.co.uk/login")!
        // Without special-casing co.uk, both of these would wrongly resolve to "co.uk"
        // and get treated as the same site. They must stay distinct.
        XCTAssertEqual(DomainResolver.registrableDomain(from: bbc), "bbc.co.uk")
        XCTAssertEqual(DomainResolver.registrableDomain(from: bank), "bank.co.uk")
        XCTAssertNotEqual(
            DomainResolver.registrableDomain(from: bbc),
            DomainResolver.registrableDomain(from: bank)
        )
    }

    // MARK: - ConflictAnalyzer — the case this whole app exists for

    func testFlagsMetaFamilyAsOneConflictGroupWithTwoDistinctPasswords() throws {
        let entries = try loadFixture()
        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertEqual(result.conflictGroups.count, 1)
        let group = result.conflictGroups[0]
        XCTAssertEqual(group.registrableDomain, "meta.com")
        XCTAssertEqual(group.entries.count, 3)
        XCTAssertEqual(group.distinctPasswords.count, 2)
    }

    func testDoesNotFlagSameDomainSamePasswordAsConflict() throws {
        // meta.com and business.meta.com share "password123" — that's fine, per spec,
        // and should not by itself create a second conflict group.
        let entries = try loadFixture()
        let result = ConflictAnalyzer.analyze(entries)
        XCTAssertEqual(result.conflictGroups.count, 1, "Should not double-count the shared-password pair as its own group")
    }

    func testFlagsReuseAcrossUnrelatedSitesAndUsernames() throws {
        // Netflix (raghav@gmail.com) and Hulu (raghav@work.com) share "sharedPass789" —
        // different username, different domain, but still password reuse.
        //
        // Note: the fixture also has "password123" reused between meta.com and
        // business.meta.com (a *within-domain* reuse, which is separately fine per the
        // conflict rule, but still counts as reuse in this password-only view) — so there
        // are two reuse groups total here, not one. Reuse detection is intentionally blind
        // to username/domain, so don't assume array order for a specific group; find it.
        let entries = try loadFixture()
        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertEqual(result.reuseGroups.count, 2)

        guard let sharedPassGroup = result.reuseGroups.first(where: { $0.password == "sharedPass789" }) else {
            XCTFail("Expected a reuse group for sharedPass789")
            return
        }
        XCTAssertEqual(sharedPassGroup.entries.count, 2)
        XCTAssertEqual(Set(sharedPassGroup.entries.map(\.username)), ["raghav@gmail.com", "raghav@work.com"])
    }

    func testDoesNotFlagDifferentDomainDifferentPasswordAsConflict() throws {
        // BBC and Bank: same username, both .co.uk, but genuinely different sites
        // and different passwords — must not be grouped together at all.
        let entries = try loadFixture()
        let result = ConflictAnalyzer.analyze(entries)
        XCTAssertFalse(result.conflictGroups.contains { $0.registrableDomain == "bbc.co.uk" })
        XCTAssertFalse(result.conflictGroups.contains { $0.registrableDomain == "bank.co.uk" })
    }

    func testUncategorizesRowsWithNoParseableDomain() throws {
        let entries = try loadFixture()
        let result = ConflictAnalyzer.analyze(entries)
        // "Note-only, comma test" (empty URL) and "Broken Row" (not a real URL) — both nil domain.
        XCTAssertEqual(result.uncategorized.count, 2)
    }

    func testEmptyPasswordNeverCountsAsAConflict() throws {
        // The note-only row has an empty password. Even though it shares a username/domain
        // key space with nothing here, this guards the rule directly.
        let entry = PasswordEntry(title: "x", url: URL(string: "https://x.com"), registrableDomain: "x.com", username: "a@b.com", password: "")
        XCTAssertFalse(entry.hasUsablePassword)
    }

    // MARK: - Notes column

    func testParsesNotesColumnWhenPresent() throws {
        let csv = "Title,URL,Username,Password,Notes\nTest,https://example.com,me@example.com,pw1,Recovery code in 1Password"
        let entries = try CSVImporter.parse(csvText: csv)
        XCTAssertEqual(entries.first?.notes, "Recovery code in 1Password")
    }

    func testMissingNotesColumnDefaultsToEmptyString() throws {
        let csv = "Title,URL,Username,Password\nTest,https://example.com,me@example.com,pw1"
        let entries = try CSVImporter.parse(csvText: csv)
        XCTAssertEqual(entries.first?.notes, "")
    }
}
