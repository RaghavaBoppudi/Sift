import XCTest
@testable import SiftCore

final class AccountGrouperTests: XCTestCase {

    func testDifferentUsernamesAndPasswordsStillGroupByBrand() {
        let entries = (1...5).map {
            makeEntry("google.com", user: "user\($0)@example.com", pass: "pass\($0)")
        }
        let groups = AccountGrouper.group(entries)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].websiteCount, 5)
        XCTAssertEqual(groups[0].distinctUsernameCount, 5)
        XCTAssertEqual(groups[0].distinctPasswordCount, 5)
    }

    func testWebsiteCountIsRowCountNotDomainCount() {
        // Two saved rows (e.g. two subdomains) resolve to one registrable domain.
        let groups = AccountGrouper.group([
            makeEntry("a24films.com", pass: "shared"),
            makeEntry("a24films.com", pass: "shared")
        ])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].websiteCount, 2)
        XCTAssertEqual(groups[0].distinctUsernameCount, 1)
        XCTAssertEqual(groups[0].distinctPasswordCount, 1)
    }

    func testUnrelatedBrandsStaySeparate() {
        XCTAssertEqual(AccountGrouper.group([makeEntry("google.com"), makeEntry("amazon.com")]).count, 2)
    }

    func testEntriesWithNoDomainBecomeStandaloneGroupsNamedByTitle() {
        let groups = AccountGrouper.group([
            makeEntry("google.com"),
            makeEntry(nil, title: "Broken Row")
        ])

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains { $0.displayDomain == "Broken Row" && $0.websiteCount == 1 })
    }

    func testNoEntryIsDropped() {
        let entries = [
            makeEntry("google.com"), makeEntry("google.com"), makeEntry("meta.com"),
            makeEntry(nil, title: "A"), makeEntry(nil, title: "B")
        ]
        let total = AccountGrouper.group(entries).reduce(0) { $0 + $1.websiteCount }

        XCTAssertEqual(total, entries.count)
    }
}
