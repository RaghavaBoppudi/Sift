import XCTest
@testable import SiftCore

final class PasswordSessionTests: XCTestCase {

    private func sampleEntries() -> [PasswordEntry] {
        [
            PasswordEntry(title: "Test Site", url: URL(string: "https://example.com"), registrableDomain: "example.com", username: "me@example.com", password: "hunter2")
        ]
    }

    func testStartsEmpty() {
        let session = PasswordSession()
        XCTAssertFalse(session.hasData)
        XCTAssertTrue(session.entries.isEmpty)
    }

    func testLoadPopulatesEntries() {
        let session = PasswordSession()
        session.load(sampleEntries())

        XCTAssertTrue(session.hasData)
        XCTAssertEqual(session.entries.count, 1)
    }

    func testResetClearsEverything() {
        let session = PasswordSession()
        session.load(sampleEntries())
        session.reset()

        XCTAssertFalse(session.hasData)
        XCTAssertTrue(session.entries.isEmpty)
    }

    func testLoadingAgainReplacesRatherThanAppends() {
        let session = PasswordSession()
        session.load(sampleEntries())

        let newEntries = [
            PasswordEntry(title: "New Site", url: URL(string: "https://new.com"), registrableDomain: "new.com", username: "x@new.com", password: "newPassword")
        ]
        session.load(newEntries)

        XCTAssertEqual(session.entries.count, 1)
        XCTAssertEqual(session.entries.first?.title, "New Site")
    }
}
