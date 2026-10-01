import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.autoLockMinutesKey) private var minutes = AppSettings.defaultAutoLockMinutes
    @AppStorage(AppSettings.blockScreenCaptureKey) private var blockScreenCapture = true

    var body: some View {
        Form {
            Section("Auto-Lock") {
                Slider(
                    value: Binding(get: { Double(minutes) }, set: { minutes = Int($0.rounded()) }),
                    in: Double(AppSettings.autoLockRange.lowerBound)...Double(AppSettings.autoLockRange.upperBound),
                    step: 1
                ) {
                    Text("Lock after \(minutes) min")
                } minimumValueLabel: {
                    Text("1")
                } maximumValueLabel: {
                    Text("30")
                }
                Text("Locks after \(minutes) minute\(minutes == 1 ? "" : "s") without clicks, key presses, or scrolling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle("Block screenshots and screen recording", isOn: $blockScreenCapture)
                Text("Leave this on. Turn it off only to share a screenshot, and avoid hovering a password while you capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
