import Foundation
import Security

/// A stable, random salt for DismissedStore — generated once, stored in this app's own
/// Keychain item, reused forever after. This is ordinary "an app storing its own secret,"
/// not the restricted "reading another app's keychain items" territory ruled out early in
/// this project — no special entitlement needed.
enum DismissedStoreSalt {
    private static let account = "dismissed-store-salt"
    private static let service = "com.raghavaboppudi.Sift"

    /// Returns the existing salt, or generates and stores a new 16-byte random one on
    /// first call. If Keychain access itself fails (very rare), falls back to a fixed
    /// in-memory salt for that run — worse than a real salt, but better than crashing;
    /// dismissed-state just won't persist across launches in that edge case.
    static func loadOrCreate() -> Data {
        if let existing = read() {
            return existing
        }
        let newSalt = randomBytes(count: 16)
        save(newSalt)
        return newSalt
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
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
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
        let result = bytes.withUnsafeMutableBytes { pointer -> Int32 in
            guard let baseAddress = pointer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        precondition(result == errSecSuccess, "SecRandomCopyBytes failed — cannot generate a salt")
        return bytes
    }
}
