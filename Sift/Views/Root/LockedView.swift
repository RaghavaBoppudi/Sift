import SwiftUI

struct LockedView: View {
    var onUnlock: () -> Void

    var body: some View {
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

            Button("Unlock", action: onUnlock)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
