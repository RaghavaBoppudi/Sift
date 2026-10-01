import XCTest
@testable import SiftCore

final class DomainResolverTests: XCTestCase {

    private func domain(_ string: String) -> String? {
        DomainResolver.registrableDomain(from: URL(string: string)!)
    }

    func testSubdomainCollapsesToRegistrableDomain() {
        XCTAssertEqual(domain("https://accounts.meta.com/login"), "meta.com")
    }

    func testTwoLabelSuffixKeepsUnrelatedSitesDistinct() {
        XCTAssertEqual(domain("https://bbc.co.uk/account"), "bbc.co.uk")
        XCTAssertEqual(domain("https://bank.co.uk/login"), "bank.co.uk")
    }

    func testIPAddressesKeepTheirFullAddress() {
        XCTAssertEqual(domain("http://192.168.1.1/admin"), "192.168.1.1")
        XCTAssertEqual(domain("http://10.0.1.1/admin"), "10.0.1.1")
    }

    func testSingleLabelHostKeepsItself() {
        XCTAssertEqual(domain("http://localhost:3000"), "localhost")
    }

    func testURLWithoutAHostHasNoDomain() {
        XCTAssertNil(domain("mailto:me@example.com"))
    }

    func testBrandLabel() {
        XCTAssertEqual(DomainResolver.brandLabel(from: "meta.com"), "meta")
        XCTAssertEqual(DomainResolver.brandLabel(from: "bbc.co.uk"), "bbc")
        XCTAssertEqual(DomainResolver.brandLabel(from: "192.168.1.1"), "192.168.1.1")
    }
}
