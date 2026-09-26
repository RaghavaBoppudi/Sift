import SwiftUI
import SiftCore

struct RootView: View {
    let appGate: AuthGate
    let session: PasswordSession
    let dismissedStore: DismissedStore

    @State private var idleTimer: IdleTimer?

    var body: some View {
        Group {
            if !appGate.isUnlocked {
                lockedScreen
            } else if !session.hasData {
                ImportView { entries, _ in
                    // sourceURL (the just-dropped file) isn't wired to a delete prompt yet —
                    // that's a small follow-up, not dropped, just not built in this pass.
                    session.load(entries)
                }
            } else {
                DashboardView(
                    session: session,
                    dismissedStore: dismissedStore,
                    appGate: appGate,
                    onReset: performReset
                )
            }
        }
        .task {
            if !appGate.isUnlocked {
                await appGate.requestUnlock()
            }
        }
        // Idle timeout only needs to manage itself now — there's no separate reveal gate
        // to cascade a lock into anymore. Once the app is unlocked, hovering a password
        // reveals it freely, same as the real Passwords app; the app-level lock is the
        // only real gate, by design (see PasswordFieldRow).
        .onChange(of: appGate.isUnlocked) { _, unlocked in
            if unlocked {
                idleTimer = IdleTimer(timeout: 30) {
                    appGate.lockNow()
                }
            } else {
                idleTimer = nil
            }
        }
        // Re-prompts every time the window becomes key while locked — matches Apple
        // Passwords' own behavior (select the window, fingerprint, done) rather than
        // requiring a manual "Unlock" click every time after the very first launch.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            if !appGate.isUnlocked {
                Task { await appGate.requestUnlock() }
            }
        }
        // TEMPORARILY DISABLED — sharingType = .none blocks all screenshots, including
        // the ones needed to show me bugs while building. WindowCaptureProtector below
        // is untouched; re-add this line before this app handles real password data
        // day-to-day.
        // .background(WindowCaptureProtector())
    }

    // MARK: - Locked

    private var lockedScreen: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)

                Image(systemName: "touchid")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
                    .padding(7)
                    .background(Circle().fill(.white))
                    .offset(x: 4, y: 4)
            }

            VStack(spacing: 6) {
                Text("Sift Is Locked")
                    .font(.title2.bold())
                Text("Touch ID or your Mac password is required to unlock Sift.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Unlock") {
                Task { await appGate.requestUnlock() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performReset() {
        session.reset()
        LastFileBookmark.clear()
        dismissedStore.clearAll()
    }
}

/// Bridges to the underlying NSWindow once it exists, to set sharingType = .none —
/// there's no SwiftUI-native way to reach the window directly, so this is the standard
/// pattern: an invisible NSView whose only job is reporting its window back.
private struct WindowCaptureProtector: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.sharingType = .none
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
