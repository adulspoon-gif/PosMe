import Foundation
import Security

/// Penyimpanan aman (Keychain iOS) untuk token login.
enum Keychain {
    private static func base(_ key: String) -> [String: Any] {
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "id.kasirpribadi.kasir",
                kSecAttrAccount as String: key]
    }

    static func set(_ value: String, for key: String) {
        var query = base(key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        var query = base(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        SecItemDelete(base(key) as CFDictionary)
    }
}
