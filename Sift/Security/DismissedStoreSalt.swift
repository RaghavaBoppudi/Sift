import Foundation
import Security

/// A stable random salt for DismissedStore, generated once and kept in this app's own
/// Keychain item. Ordinary "app stores its own secret"; no special entitlement.
enum DismissedStoreSalt {
    private static let account = "dismissed-store-salt"
    private static let service = "com.raghavaboppudi.Sift"

    /// If the Keychain write fails, the returned salt is valid for this launch only and
    /// dismissals won't match on the next one.
    static func loadOrCreate() -> Data {
        if let existing = read() { return existing }
        let salt = randomBytes(count: 16)
        save(salt)
        return salt
    }

    private static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func save(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, base)
        }
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed; cannot generate a salt")
        return bytes
    }
}
