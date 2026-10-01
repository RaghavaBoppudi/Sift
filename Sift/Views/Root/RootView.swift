import SwiftUI
import SiftCore

struct RootView: View {
    let appGate: AuthGate
    let session: PasswordSession
    let dismissedStore: DismissedStore

    @AppStorage(AppSettings.autoLockMinutesKey) private var autoLockMinutes = AppSettings.defaultAutoLockMinutes
    @AppStorage(AppSettings.blockScreenCaptureKey) private var blockScreenCapture = true
    @State private var idleTimer: IdleTimer?
    @State private var exportedFile: URL?

    var body: some View {
        Group {
            if !appGate.isUnlocked {
                LockedView { Task { await appGate.requestUnlock() } }
            } else if !session.hasData {
                ImportView { entries, droppedFile in
                    session.load(entries)
                    exportedFile = droppedFile
                }
            } else {
                DashboardView(
                    entries: session.entries,
                    dismissedStore: dismissedStore,
                    appGate: appGate,
                    onReset: performReset
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if appGate.isUnlocked, let file = exportedFile {
                ExportedFileBanner(file: file, onTrash: { trash(file) }, onKeep: { exportedFile = nil })
            }
        }
        .captureProtected(blockScreenCapture)
        .task { await appGate.requestUnlock(automatic: true) }
        .onChange(of: appGate.isUnlocked) { syncIdleTimer() }
        .onChange(of: autoLockMinutes) { syncIdleTimer() }
        // Re-prompt when the person switches back to the app. AuthGate stays quiet after a
        // cancelled prompt, so dismissing the system dialog doesn't re-open it.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await appGate.requestUnlock(automatic: true) }
        }
    }

    private func syncIdleTimer() {
        idleTimer?.stop()
        idleTimer = appGate.isUnlocked
            ? IdleTimer(timeout: AppSettings.autoLockSeconds(forMinutes: autoLockMinutes)) { appGate.lockNow() }
            : nil
    }

    private func performReset() {
        session.reset()
        LastFileBookmark.clear()
        dismissedStore.clearAll()
    }

    /// If trashing fails (the sandbox may not allow it), reveal the file so the person can
    /// delete it themselves. The bookmark is cleared only on success; otherwise "Reload
    /// last file" would follow it into the Trash.
    private func trash(_ file: URL) {
        defer { exportedFile = nil }
        do {
            try FileManager.default.trashItem(at: file, resultingItemURL: nil)
            LastFileBookmark.clear()
        } catch {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
    }
}
