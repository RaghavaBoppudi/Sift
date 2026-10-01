import AppKit
import LocalAuthentication
import Observation

/// Gates the whole app behind Touch ID / the device password. There is one identity (this
/// Mac's account), so there is no passphrase layer. Lives for the app's lifetime, which is
/// why its notification observers are never removed.
@MainActor
@Observable
final class AuthGate {
    private(set) var isUnlocked = false

    /// RootView has several triggers that can ask for an unlock at nearly the same moment
    /// (first appearance, app activation on cold launch). Overlapping LocalAuthentication
    /// calls caused a visible stutter, so a second request awaits the one already running.
    @ObservationIgnored private var inFlight: Task<Bool, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// After a failed or cancelled attempt, automatic triggers (launch, app activation) stay
    /// quiet until the person presses Unlock. Dismissing the system prompt re-activates the
    /// app, which would otherwise immediately re-open the prompt, forever.
    @ObservationIgnored private var autoPromptSuppressed = false

    init() {
        // Screen lock and sleep re-lock the app unconditionally. The auto-lock timer
        // setting cannot override these; they're OS signals the person didn't have to
        // remember to act on.
        let lockSignals: [(NotificationCenter, Notification.Name)] = [
            (DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsLocked")),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification)
        ]
        for (center, name) in lockSignals {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lockNow() }
            })
        }
    }

    /// `automatic` is true for triggers the person didn't explicitly ask for. The system
    /// prompt already reads "Sift is trying to…", so `reason` must complete that sentence
    /// and must not repeat the app name.
    @discardableResult
    func requestUnlock(automatic: Bool = false, reason: String = "access your saved passwords") async -> Bool {
        guard !isUnlocked else { return true }
        if automatic && autoPromptSuppressed { return false }
        if let inFlight { return await inFlight.value }

        let task = Task { await Self.authenticate(reason: reason) }
        inFlight = task
        let success = await task.value
        inFlight = nil
        isUnlocked = success
        autoPromptSuppressed = !success
        return success
    }

    func lockNow() {
        isUnlocked = false
        autoPromptSuppressed = false
    }

    private nonisolated static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        // No Touch ID and no device password: must not pretend to unlock.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
