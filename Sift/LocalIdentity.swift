import Foundation
import AppKit
import OpenDirectory

/// Reads this Mac account's own name and photo directly from the local OpenDirectory
/// record — the same place System Settings' account picture comes from. Deliberately NOT
/// the Contacts framework: that's a different store entirely (an iCloud card you'd have to
/// explicitly grant access to) and isn't what shows your login picture.
///
/// ⚠️ The photo lookup is the least-certain piece of this whole app. It's never been run —
/// there's no way to compile-check OpenDirectory's Swift bridging without Xcode, and under
/// App Sandbox this kind of directory-service read can behave differently than outside one.
/// If accountImage() returns nil, that's treated as the ordinary case (show initials
/// instead), not a crash — so a failure here degrades gracefully rather than breaking
/// anything. If it doesn't work at all, tell me and we'll either debug the ODQuery call or
/// just drop this in favor of name-only, which is guaranteed to work.
enum LocalIdentity {

    /// Always works — Foundation, no directory service call, no entitlement.
    static var fullName: String {
        NSFullUserName()
    }

    /// Best-effort. Returns nil on any failure — missing photo, sandbox restriction,
    /// whatever — rather than throwing, since "no photo" is a normal, expected outcome.
    static func accountImage() -> NSImage? {
        guard
            let session = try? ODSession.default(),
            let node = try? ODNode(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
        else {
            return nil
        }

        guard let query = try? ODQuery(
            node: node,
            forRecordTypes: kODRecordTypeUsers,
            attribute: kODAttributeTypeRecordName,
            matchType: ODMatchType(kODMatchEqualTo),
            queryValues: NSUserName(),
            returnAttributes: kODAttributeTypeJPEGPhoto,
            maximumResults: 1
        ) else {
            return nil
        }

        guard
            let results = try? query.resultsAllowingPartial(false) as? [ODRecord],
            let record = results.first,
            let values = try? record.values(forAttribute: kODAttributeTypeJPEGPhoto) as? [Data],
            let imageData = values.first
        else {
            return nil
        }

        return NSImage(data: imageData)
    }
}
