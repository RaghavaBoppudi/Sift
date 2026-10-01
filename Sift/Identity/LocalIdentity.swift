import Foundation
import OpenDirectory

/// This Mac account's photo, read from the local OpenDirectory record (where System
/// Settings' account picture lives). Not the Contacts framework, which is a different store.
///
/// UNVERIFIED: never compiled or run. OpenDirectory reads can behave differently under App
/// Sandbox. Any failure returns nil and the UI shows a generic avatar. It's a blocking
/// call, so run it off the main thread. If it doesn't work, delete this file and the
/// avatar toolbar item.
enum LocalIdentity {

    nonisolated static func accountImageData() -> Data? {
        guard
            let session = try? ODSession.default(),
            let node = try? ODNode(session: session, type: ODNodeType(kODNodeTypeLocalNodes)),
            let query = try? ODQuery(
                node: node,
                forRecordTypes: kODRecordTypeUsers,
                attribute: kODAttributeTypeRecordName,
                matchType: ODMatchType(kODMatchEqualTo),
                queryValues: NSUserName(),
                returnAttributes: kODAttributeTypeJPEGPhoto,
                maximumResults: 1
            ),
            let results = try? query.resultsAllowingPartial(false) as? [ODRecord],
            let record = results.first,
            let values = try? record.values(forAttribute: kODAttributeTypeJPEGPhoto) as? [Data]
        else {
            return nil
        }
        return values.first
    }
}
