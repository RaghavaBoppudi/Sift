import Foundation
import LocalAuthentication
import Observation

/// Two of these exist: one gates the app itself, one gates the first password reveal each
/// session. Both are plain Touch ID / device-password checks — no per-identity passphrase
/// layer anymore, since there's only one identity (this Mac's account) to protect.
@Observable
final class AuthGate {
    private(set) var isUnlocked: Bool = false

    private var screenLockObserver: NSObjectProtocol?
    /// Guards against two overlapping evaluatePolicy calls — RootView has more than one
    /// trigger that can call requestUnlock() around the same moment (first appearance,
    /// and the window becoming key, which also fires on the very first cold launch), and
    /// firing LocalAuthentication twice concurrently is exactly what caused the visible
    /// stutter on launch. A second call while one is already running just awaits the
    /// same in-flight result instead of starting a new prompt.
    private var inFlightUnlock: Task<Bool, Never>?

    init() {
        observeScreenLock()
    }

    deinit {
        if let screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(screenLockObserver)
        }
    }

    /// Prompts Touch ID / device password. Returns true on success.
    /// The system prompt already says "Sift is trying to..." before this string — so this
    /// completes that sentence and must NOT repeat the app name or say "unlock Sift" again,
    /// or the dialog reads as "Sift is trying to unlock Sift."
    @discardableResult
    func requestUnlock(reason: String = "access your saved passwords") async -> Bool {
        if let inFlightUnlock {
            return await inFlightUnlock.value
        }

        let task = Task<Bool, Never> {
            let context = LAContext()
            var evaluationError: NSError?

            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
                // No Touch ID, no device password set at all — extremely rare on a real
                // Mac, but must not silently pretend to unlock if it happens.
                return false
            }

            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                // Touch ID's completion doesn't guarantee it resumes on the main thread —
                // mutating @Observable state off-main is exactly the kind of thing a
                // debugger-attached run can paper over while a standalone launch just crashes.
                await MainActor.run { self.isUnlocked = success }
                return success
            } catch {
                await MainActor.run { self.isUnlocked = false }
                return false
            }
        }
        inFlightUnlock = task
        let result = await task.value
        inFlightUnlock = nil
        return result
    }

    /// Manual "hide everything now" — the corner button, independent of any timer.
    func lockNow() {
        isUnlocked = false
    }

    // MARK: - Automatic lock on screen lock

    /// Forces isUnlocked back to false the instant the screen locks, regardless of the
    /// manual button or the configurable auto-lock timer. This is deliberately not
    /// something the auto-lock timer setting can override — screen-lock is an OS-level
    /// signal the person didn't have to remember to act on themselves.
    private func observeScreenLock() {
        screenLockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lockNow()
        }
    }
}
