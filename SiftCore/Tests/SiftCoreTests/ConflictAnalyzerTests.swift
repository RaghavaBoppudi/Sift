import XCTest
@testable import SiftCore

final class ConflictAnalyzerTests: XCTestCase {

    // MARK: - Conflicts

    func testDifferentPasswordsOnOneDomainConflict() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("google.com", pass: "p1"),
            makeEntry("google.com", pass: "p2")
        ])

        XCTAssertEqual(result.conflictGroups.count, 1)
        XCTAssertEqual(result.conflictGroups[0].distinctPasswords.count, 2)
    }

    func testSharedPasswordIsNotAConflict() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("meta.com", pass: "same"),
            makeEntry("metacareers.com", pass: "same")
        ])

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }

    func testBrandRelatedDomainsConflictAndShowTheShortestDomain() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("metacareers.com", pass: "p1"),
            makeEntry("meta.com", pass: "p2")
        ])

        XCTAssertEqual(result.conflictGroups.count, 1)
        XCTAssertEqual(result.conflictGroups[0].registrableDomain, "meta.com")
        XCTAssertEqual(result.conflictGroups[0].domains, ["meta.com", "metacareers.com"])
    }

    func testUsernamesMatchCaseInsensitively() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("meta.com", user: "Me@Example.com", pass: "p1"),
            makeEntry("meta.com", user: "me@example.com", pass: "p2")
        ])

        XCTAssertEqual(result.conflictGroups.count, 1)
    }

    func testDifferentUsernamesNeverConflict() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("meta.com", user: "a@example.com", pass: "p1"),
            makeEntry("meta.com", user: "b@example.com", pass: "p2")
        ])

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }

    func testBlankPasswordNeverCountsAsADifferentPassword() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("meta.com", pass: ""),
            makeEntry("meta.com", pass: "p1")
        ])

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }

    func testEmptyUsernamesAreIgnored() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("meta.com", user: "", pass: "p1"),
            makeEntry("meta.com", user: "", pass: "p2")
        ])

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }

    func testDistinctIPAddressesDoNotFalselyConflict() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("192.168.1.1", user: "admin", pass: "p1"),
            makeEntry("192.168.1.10", user: "admin", pass: "p2")
        ])

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }

    func testEntriesWithNoDomainAreNeverAnalyzed() {
        let result = ConflictAnalyzer.analyze([
            makeEntry(nil, pass: "p1"),
            makeEntry(nil, pass: "p2")
        ])

        XCTAssertTrue(result.conflictGroups.isEmpty)
        XCTAssertTrue(result.reuseGroups.isEmpty)
    }

    // MARK: - Reuse

    func testSamePasswordOnUnrelatedSitesIsReuse() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("netflix.com", user: "a@gmail.com", pass: "shared"),
            makeEntry("hulu.com", user: "a@work.com", pass: "shared")
        ])

        XCTAssertEqual(result.reuseGroups.count, 1)
        XCTAssertEqual(result.reuseGroups[0].entries.count, 2)
        XCTAssertEqual(result.reuseGroups[0].domains, ["hulu.com", "netflix.com"])
    }

    func testSamePasswordWithinOneBrandIsNotReuse() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("meta.com", pass: "shared"),
            makeEntry("metacareers.com", pass: "shared")
        ])

        XCTAssertTrue(result.reuseGroups.isEmpty)
    }

    func testBlankPasswordsAreNotReuse() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("netflix.com", pass: ""),
            makeEntry("hulu.com", pass: "")
        ])

        XCTAssertTrue(result.reuseGroups.isEmpty)
    }

    func testLargestReuseGroupSortsFirst() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("a-site.com", pass: "two"), makeEntry("b-site.com", pass: "two"),
            makeEntry("c-site.com", pass: "three"), makeEntry("d-site.com", pass: "three"),
            makeEntry("e-site.com", pass: "three")
        ])

        XCTAssertEqual(result.reuseGroups.map(\.entries.count), [3, 2])
    }

    func testRepeatedSavesOfTheSameLoginCollapseInTheAccountList() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("utdallas.edu", user: "me@utdallas.edu", pass: "shared"),
            makeEntry("utdallas.edu", user: "me@utdallas.edu", pass: "shared"),
            makeEntry("utdallas.edu", user: "me@utdallas.edu", pass: "shared"),
            makeEntry("coursera.org", user: "me@utdallas.edu", pass: "shared"),
            makeEntry("github.com", user: "me@utdallas.edu", pass: "shared")
        ])

        XCTAssertEqual(result.reuseGroups.count, 1)
        XCTAssertEqual(result.reuseGroups[0].entries.count, 5)
        XCTAssertEqual(result.reuseGroups[0].accounts.count, 3)
    }

    func testDifferentUsernamesOnTheSameSiteStayDistinctInTheAccountList() {
        let result = ConflictAnalyzer.analyze([
            makeEntry("utdallas.edu", user: "a@utdallas.edu", pass: "shared"),
            makeEntry("utdallas.edu", user: "b@utdallas.edu", pass: "shared"),
            makeEntry("github.com", user: "a@utdallas.edu", pass: "shared")
        ])

        XCTAssertEqual(result.reuseGroups[0].accounts.count, 3)
    }
}
