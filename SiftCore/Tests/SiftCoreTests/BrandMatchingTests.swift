import XCTest
@testable import SiftCore

final class BrandMatchingTests: XCTestCase {

    private func entry(title: String, domain: String, username: String, password: String) -> PasswordEntry {
        PasswordEntry(
            title: title,
            url: URL(string: "https://\(domain)"),
            registrableDomain: domain,
            username: username,
            password: password
        )
    }

    func testMetaAndMetaCareersAreTreatedAsOneBrand() {
        // The real-world case this feature exists for: two genuinely different
        // registrable domains, same underlying product, different passwords saved.
        let entries = [
            entry(title: "Meta", domain: "meta.com", username: "me@example.com", password: "pass1"),
            entry(title: "Meta Careers", domain: "metacareers.com", username: "me@example.com", password: "pass2")
        ]

        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertEqual(result.conflictGroups.count, 1)
        XCTAssertEqual(result.conflictGroups.first?.entries.count, 2)
        // Shortest domain in the cluster is the representative one shown to the user.
        XCTAssertEqual(result.conflictGroups.first?.registrableDomain, "meta.com")
    }

    func testInstagramAndFacebookAreNotGrouped() {
        // Same corporate owner, unrelated brand names — explicitly NOT supposed to
        // match. This is the exact distinction the feature was scoped around.
        let entries = [
            entry(title: "Instagram", domain: "instagram.com", username: "me@example.com", password: "passA"),
            entry(title: "Facebook", domain: "facebook.com", username: "me@example.com", password: "passB")
        ]

        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertTrue(result.conflictGroups.isEmpty, "Unrelated brand names must not be clustered together")
    }

    func testTransitiveChainClustersAllThree() {
        // A relates to B (prefix), B relates to C (prefix), but A is not a prefix of C.
        // All three must still land in one cluster via transitive closure, not just
        // whichever pair happens to match directly.
        let entries = [
            entry(title: "A", domain: "meta.com", username: "me@example.com", password: "p1"),
            entry(title: "B", domain: "metacareers.com", username: "me@example.com", password: "p2"),
            entry(title: "C", domain: "metacareersportal.com", username: "me@example.com", password: "p1")
        ]

        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertEqual(result.conflictGroups.count, 1)
        XCTAssertEqual(result.conflictGroups.first?.entries.count, 3)
    }

    func testShortLabelsDoNotFalsePositiveMatch() {
        // "ab" is technically a prefix of "abcompany", but at 2 characters it's exactly
        // the kind of coincidental short-string collision the length guard exists for.
        let entries = [
            entry(title: "AB", domain: "ab.com", username: "me@example.com", password: "p1"),
            entry(title: "AB Company", domain: "abcompany.com", username: "me@example.com", password: "p2")
        ]

        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertTrue(result.conflictGroups.isEmpty, "Short labels under the length guard must not match")
    }

    func testDifferentUsernamesNeverClusterRegardlessOfBrand() {
        // Brand matching only ever applies within the same username — this isn't a new
        // rule, but worth pinning down now that domain matching got more permissive.
        let entries = [
            entry(title: "Meta", domain: "meta.com", username: "a@example.com", password: "p1"),
            entry(title: "Meta Careers", domain: "metacareers.com", username: "b@example.com", password: "p2")
        ]

        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }

    func testSameBrandSamePasswordIsNotFlagged() {
        // Brand-related domains sharing one password is the "fine" case, same as
        // same-domain reuse always was — only differing passwords should flag.
        let entries = [
            entry(title: "Meta", domain: "meta.com", username: "me@example.com", password: "sharedPass"),
            entry(title: "Meta Careers", domain: "metacareers.com", username: "me@example.com", password: "sharedPass")
        ]

        let result = ConflictAnalyzer.analyze(entries)

        XCTAssertTrue(result.conflictGroups.isEmpty)
    }
}
