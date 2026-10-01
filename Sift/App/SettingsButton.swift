import SwiftUI
import AppKit

/// Toolbar toggle for the Settings window: opens it, and closes it if it's already open.
/// SettingsLink can only open, so a second click re-triggered the window instead of
/// dismissing it. ⌘, still opens Settings as usual.
struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "gearshape")
        }
        .help("Settings")
    }

    private func toggle() {
        if let window = Self.settingsWindow, window.isVisible {
            window.close()
        } else {
            openSettings()
        }
    }

    /// SwiftUI doesn't expose the Settings window, so it's found by its identifier or title.
    private static var settingsWindow: NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true
                || $0.title == "Settings"
        }
    }
}
