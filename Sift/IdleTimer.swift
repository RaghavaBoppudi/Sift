import AppKit

/// Fires a callback after a period of no user interaction. Uses a LOCAL event monitor
/// deliberately — it only sees events inside this app's own windows, not system-wide
/// activity, so it needs no special permission (a global monitor would require
/// Accessibility access, a much bigger ask for a simple idle-lock).
///
/// Resets on clicks, key presses, and scrolling. Does NOT reset on pure mouse movement
/// with no click — that needs the underlying NSWindow's acceptsMouseMovedEvents enabled,
/// which isn't cleanly reachable from SwiftUI without extra plumbing. For "walked away
/// and forgot," click/key/scroll activity covers the realistic case.
@MainActor
final class IdleTimer {
    private let timeout: TimeInterval
    private let onTimeout: () -> Void
    private var timer: Timer?
    private var monitor: Any?

    init(timeout: TimeInterval = 30, onTimeout: @escaping () -> Void) {
        self.timeout = timeout
        self.onTimeout = onTimeout
        start()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        timer?.invalidate()
    }

    private func start() {
        resetTimer()
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.resetTimer()
            return event
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.onTimeout()
            }
        }
    }
}
