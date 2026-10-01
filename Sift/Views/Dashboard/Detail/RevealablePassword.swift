import SwiftUI

/// Reveals while hovered; click copies. No separate reveal-time authentication: the
/// app-level lock is the only gate, by design (same as Apple's Passwords once unlocked).
struct RevealablePassword: View {
    let password: String
    @State private var isHovering = false
    @State private var justCopied = false

    var body: some View {
        Text(justCopied ? "Copied" : (isHovering ? password : "••••••••"))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(isHovering || justCopied ? .primary : .secondary)
            .onHover { isHovering = $0 }
            .onTapGesture {
                SecurePasteboard.copy(password)
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopied = false }
            }
            .help("Click to copy")
    }
}
