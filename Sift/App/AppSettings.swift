import Foundation

/// UserDefaults keys and limits shared by Settings and the views that read them.
enum AppSettings {
    static let autoLockMinutesKey = "autoLockMinutes"
    static let defaultAutoLockMinutes = 5
    static let autoLockRange = 1...30

    static let blockScreenCaptureKey = "blockScreenCapture"

    /// Clamped, since the stored value can be edited outside the app.
    static func autoLockSeconds(forMinutes minutes: Int) -> TimeInterval {
        TimeInterval(min(max(minutes, autoLockRange.lowerBound), autoLockRange.upperBound) * 60)
    }
}
