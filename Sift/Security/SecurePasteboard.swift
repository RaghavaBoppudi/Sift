import AppKit

enum SecurePasteboard {
    /// nspasteboard.org convention: clipboard managers that honor it skip this item, so the
    /// password doesn't land in their history.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Copies, then clears after `seconds` — but only if nothing else was copied since
    /// (changeCount moves on every write), so an unrelated copy is never wiped.
    static func copy(_ string: String, clearAfter seconds: TimeInterval = 30) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        item.setString(string, forType: .string)
        item.setData(Data(), forType: concealedType)
        _ = pasteboard.writeObjects([item])

        let changeCount = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if pasteboard.changeCount == changeCount {
                pasteboard.clearContents()
            }
        }
    }
}
