import XCTest
@testable import SiftCore

final class PasswordSessionTests: XCTestCase {

    func testStartsEmpty() {
        let session = PasswordSession()

        XCTAssertFalse(session.hasData)
        XCTAssertTrue(session.entries.isEmpty)
    }

    func testLoadReplacesRatherThanAppends() {
        let session = PasswordSession()
        session.load([makeEntry("example.com")])
        session.load([makeEntry("new.com")])

        XCTAssertTrue(session.hasData)
        XCTAssertEqual(session.entries.count, 1)
        XCTAssertEqual(session.entries.first?.registrableDomain, "new.com")
    }

    func testResetClearsEverything() {
        let session = PasswordSession()
        session.load([makeEntry("example.com")])
        session.reset()

        XCTAssertFalse(session.hasData)
    }
}
