import XCTest
@testable import SiftCore

final class AccountGroupingTests: XCTestCase {

    private func entry(title: String, domain: String, username: String, password: String) -> PasswordEntry {
        PasswordEntry(
            title: title,
            url: URL(string: "https://\(domain)"),
            registrableDomain: domain,
            username: username,
            password: password
        )
    }

    func testDifferentUsernamesStillGroupTogether() {
        // The exact case ConflictGroup deliberately does NOT catch: five different
        // Google logins, five different passwords — not a "conflict" by that definition,
        // but still one brand worth seeing as a single account cluster.
        let entries = (1...5).map {
            entry(title: "Google \($0)", domain: "google.com", username: "user\($0)@example.com", password: "pass\($0)")
        }

        let groups = ConflictAnalyzer.groupByAccount(entries)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.entries.count, 5)
        XCTAssertEqual(groups.first?.distinctUsernameCount, 5)
        XCTAssertEqual(groups.first?.distinctPasswordCount, 5)
    }

    func testWebsiteCountIsRowCountNotDomainCount() {
        // Two different subdomains under one brand, same username/password — matches the
        // real-world A24 case this feature was built around.
        let entries = [
            entry(title: "A24", domain: "account.a24films.com", username: "me@example.com", password: "shared"),
            entry(title: "A24", domain: "aaa24.a24films.com", username: "me@example.com", password: "shared")
        ]

        let groups = ConflictAnalyzer.groupByAccount(entries)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.websiteCount, 2)
        XCTAssertEqual(groups.first?.distinctUsernameCount, 1)
        XCTAssertEqual(groups.first?.distinctPasswordCount, 1)
    }

    func testUnrelatedBrandsStayInDifferentGroups() {
        let entries = [
            entry(title: "Google", domain: "google.com", username: "me@example.com", password: "p1"),
            entry(title: "Amazon", domain: "amazon.com", username: "me@example.com", password: "p2")
        ]

        let groups = ConflictAnalyzer.groupByAccount(entries)

        XCTAssertEqual(groups.count, 2)
    }
}
