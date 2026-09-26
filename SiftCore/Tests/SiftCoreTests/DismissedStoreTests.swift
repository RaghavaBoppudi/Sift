import XCTest
@testable import SiftCore

final class DismissedStoreTests: XCTestCase {

    private let testSalt = Data("test-salt-not-random".utf8)

    private final class InMemoryPersistence: DismissedStorePersisting {
        var stored: Set<String> = []
        func loadHashes() -> Set<String> { stored }
        func saveHashes(_ hashes: Set<String>) { stored = hashes }
    }

    // MARK: - Core hashing/membership logic

    func testDismissAndCheckRoundTrip() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: testSalt)

        XCTAssertFalse(store.isDismissed(username: "me@example.com", domain: "meta.com"))
        store.dismiss(username: "me@example.com", domain: "meta.com")
        XCTAssertTrue(store.isDismissed(username: "me@example.com", domain: "meta.com"))
    }

    func testUsernameAndDomainAreCaseInsensitive() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: testSalt)

        store.dismiss(username: "Me@Example.com", domain: "Meta.COM")
        XCTAssertTrue(store.isDismissed(username: "me@example.com", domain: "meta.com"))
    }

    func testClearAllRemovesEverything() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: testSalt)

        store.dismiss(username: "a@example.com", domain: "meta.com")
        store.dismiss(username: "b@example.com", domain: "netflix.com")
        store.clearAll()

        XCTAssertFalse(store.isDismissed(username: "a@example.com", domain: "meta.com"))
        XCTAssertFalse(store.isDismissed(username: "b@example.com", domain: "netflix.com"))
    }

    func testConflictGroupConvenienceOverload() {
        let store = DismissedStore(persistence: InMemoryPersistence(), salt: testSalt)
        let entry = PasswordEntry(title: "x", url: URL(string: "https://meta.com"), registrableDomain: "meta.com", username: "me@example.com", password: "p1")
        let group = ConflictGroup(username: "me@example.com", registrableDomain: "meta.com", entries: [entry])

        XCTAssertFalse(store.isDismissed(group))
        store.dismiss(group)
        XCTAssertTrue(store.isDismissed(group))
    }

    // MARK: - Real file persistence

    func testDismissalSurvivesANewStoreInstance() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dismissed-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let firstStore = DismissedStore(
            persistence: FileDismissedStorePersistence(fileURL: tempFile),
            salt: testSalt
        )
        firstStore.dismiss(username: "me@example.com", domain: "meta.com")

        let secondStore = DismissedStore(
            persistence: FileDismissedStorePersistence(fileURL: tempFile),
            salt: testSalt
        )
        XCTAssertTrue(secondStore.isDismissed(username: "me@example.com", domain: "meta.com"))
    }

    func testPersistedFileContainsNoPlaintextUsernameOrDomain() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dismissed-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let store = DismissedStore(
            persistence: FileDismissedStorePersistence(fileURL: tempFile),
            salt: testSalt
        )
        store.dismiss(username: "raghav@gmail.com", domain: "meta.com")

        let rawFileContents = try String(contentsOf: tempFile, encoding: .utf8)
        XCTAssertFalse(rawFileContents.contains("raghav"))
        XCTAssertFalse(rawFileContents.contains("meta.com"))
    }

    func testEmptyOrMissingFileLoadsAsEmptySet() {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")

        let store = DismissedStore(
            persistence: FileDismissedStorePersistence(fileURL: tempFile),
            salt: testSalt
        )
        XCTAssertFalse(store.isDismissed(username: "anyone@example.com", domain: "any.com"))
    }
}
