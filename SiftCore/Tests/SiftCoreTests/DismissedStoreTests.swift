import XCTest
@testable import SiftCore

final class DismissedStoreTests: XCTestCase {

    private let salt = Data("test-salt-not-random".utf8)

    private final class InMemoryPersistence: DismissedStorePersisting {
        var stored: Set<String> = []
        func loadHashes() -> Set<String> { stored }
        func saveHashes(_ hashes: Set<String>) { stored = hashes }
    }

    private func group(
        user: String = "me@example.com",
        _ passwordsByDomain: [(String, String)] = [("meta.com", "p1"), ("metacareers.com", "p2")]
    ) -> ConflictGroup {
        ConflictGroup(
            username: user,
            entries: passwordsByDomain.map { makeEntry($0.0, user: user, pass: $0.1) }
        )
    }

    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("dismissed-\(UUID().uuidString).json")
    }

    func testDismissAndCheckRoundTrip() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: salt)

        XCTAssertFalse(store.isDismissed(group()))
        store.dismiss(group())
        XCTAssertTrue(store.isDismissed(group()))
    }

    func testUsernameIsCaseInsensitive() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: salt)

        store.dismiss(group(user: "Me@Example.com"))
        XCTAssertTrue(store.isDismissed(group(user: "me@example.com")))
    }

    func testDismissalIsKeyedOnDomainsNotPasswords() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: salt)
        store.dismiss(group([("meta.com", "p1"), ("metacareers.com", "p2")]))

        XCTAssertTrue(store.isDismissed(group([("meta.com", "p1"), ("metacareers.com", "changed")])))
    }

    func testDifferentDomainSetIsNotDismissed() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: salt)
        store.dismiss(group([("meta.com", "p1"), ("metacareers.com", "p2")]))

        XCTAssertFalse(store.isDismissed(group([("meta.com", "p1"), ("metacafe.com", "p2")])))
    }

    func testDifferentUsernameIsNotDismissed() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: salt)
        store.dismiss(group(user: "a@example.com"))

        XCTAssertFalse(store.isDismissed(group(user: "b@example.com")))
    }

    func testClearAllRemovesEverything() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: salt)
        store.dismiss(group(user: "a@example.com"))
        store.dismiss(group(user: "b@example.com"))
        store.clearAll()

        XCTAssertFalse(store.isDismissed(group(user: "a@example.com")))
        XCTAssertFalse(store.isDismissed(group(user: "b@example.com")))
    }

    func testDismissalSurvivesANewStoreInstance() {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        DismissedStore(persistence: FileDismissedStorePersistence(fileURL: file), salt: salt)
            .dismiss(group())
        let reopened = DismissedStore(persistence: FileDismissedStorePersistence(fileURL: file), salt: salt)

        XCTAssertTrue(reopened.isDismissed(group()))
    }

    func testPersistedFileContainsNoPlaintext() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        DismissedStore(persistence: FileDismissedStorePersistence(fileURL: file), salt: salt)
            .dismiss(group(user: "raghav@gmail.com"))
        let raw = try String(contentsOf: file, encoding: .utf8)

        XCTAssertFalse(raw.contains("raghav"))
        XCTAssertFalse(raw.contains("meta"))
    }

    func testMissingFileLoadsAsEmpty() {
        let store = DismissedStore(persistence: FileDismissedStorePersistence(fileURL: tempFile()), salt: salt)

        XCTAssertFalse(store.isDismissed(group()))
    }
}
