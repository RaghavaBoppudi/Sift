import SwiftUI
import SiftCore

@main
struct SiftApp: App {
    @State private var appGate = AuthGate()
    private let session = PasswordSession()
    private let dismissedStore: DismissedStore

    init() {
        dismissedStore = Self.makeDismissedStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView(appGate: appGate, session: session, dismissedStore: dismissedStore)
                .frame(minWidth: 960, minHeight: 560)
        }
    }

    private static func makeDismissedStore() -> DismissedStore {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.raghavaboppudi.sift"
        let directory = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("dismissed.json")
        let salt = DismissedStoreSalt.loadOrCreate()
        return DismissedStore(persistence: FileDismissedStorePersistence(fileURL: fileURL), salt: salt)
    }
}
