import Foundation
import Security

/// Thin wrapper over the generic-password keychain used for BYOK provider keys and connected-account
/// tokens.
///
/// Three properties matter for the values we store here:
/// * **Scoped by service.** Items are namespaced under the app's service identifier instead of
///   sitting in the account-only namespace shared with anything else on the keychain.
/// * **Not backed up.** `…ThisDeviceOnly` keeps API keys out of iCloud/iTunes backups, so a restored
///   or exfiltrated backup can't hand someone the user's billable provider keys.
/// * **Available after first unlock**, so App Intents / widget refreshes that run before the user
///   opens the app can still read them.
struct KeychainHelper {
    private static let service = "com.personalshooper.app"
    // `kSecAttrAccessible*` values are immutable CFString constants; the compiler just can't see
    // that through the CoreFoundation import.
    private static var accessibility: CFString { kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    /// Pre-namespacing query, kept so keys saved by older builds are still readable (and get
    /// migrated on first read).
    private static func legacyQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
    }

    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }

        var query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { current, _ in current }
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func load(for key: String) -> String? {
        if let value = read(query: baseQuery(for: key)) {
            return value
        }

        // Migrate a value written before the service namespace existed. The legacy delete must run
        // *before* the namespaced save: the legacy query has no service constraint, so it matches
        // any item with this account — including the one we're about to write.
        guard let legacyValue = read(query: legacyQuery(for: key)) else { return nil }
        SecItemDelete(legacyQuery(for: key) as CFDictionary)
        save(legacyValue, for: key)
        return legacyValue
    }

    static func delete(for key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
        SecItemDelete(legacyQuery(for: key) as CFDictionary)
    }

    private static func read(query: [String: Any]) -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}
