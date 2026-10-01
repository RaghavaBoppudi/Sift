import AppKit

/// Calls `onTimeout` after a period with no clicks, key presses, or scrolling inside this
/// app's windows. A local event monitor needs no permission; a global one would need
/// Accessibility access. Pure mouse movement does not reset it (that would need the
/// window's acceptsMouseMovedEvents), which is fine for "walked away and forgot".
///
/// Call `stop()` before discarding it; there is deliberately no deinit cleanup.
@MainActor
final class IdleTimer {
    private let timeout: TimeInterval
    private let onTimeout: () -> Void
    private var timer: Timer?
    private var monitor: Any?

    init(timeout: TimeInterval, onTimeout: @escaping () -> Void) {
        self.timeout = timeout
        self.onTimeout = onTimeout
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.resetTimer() }
            return event
        }
        resetTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.onTimeout() }
        }
    }
}
