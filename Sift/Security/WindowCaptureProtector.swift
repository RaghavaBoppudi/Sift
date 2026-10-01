import SwiftUI
import AppKit

extension View {
    /// Blocks screenshots and screen recording of the window while `enabled` is true.
    /// Driven by the "Block screenshots" setting, which defaults to on.
    func captureProtected(_ enabled: Bool) -> some View {
        background(WindowCaptureProtector(isEnabled: enabled))
    }
}

private struct WindowCaptureProtector: NSViewRepresentable {
    let isEnabled: Bool

    func makeNSView(context: Context) -> CaptureProtectorView {
        let view = CaptureProtectorView()
        view.isProtected = isEnabled
        return view
    }

    func updateNSView(_ view: CaptureProtectorView, context: Context) {
        view.isProtected = isEnabled
    }
}

private final class CaptureProtectorView: NSView {
    var isProtected = true { didSet { apply() } }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    private func apply() {
        window?.sharingType = isProtected ? .none : .readOnly
    }
}
