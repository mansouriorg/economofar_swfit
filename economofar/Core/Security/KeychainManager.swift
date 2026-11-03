import Foundation
import Security

/// Stores the JWT in the iOS Keychain instead of UserDefaults.
///
/// Old versions of the app kept the token in UserDefaults ("jwt_token").
/// `loadToken()` migrates it automatically the first time, so nobody is logged out.
enum KeychainManager {
    private static let service = "com.economofar.app.auth"
    private static let tokenAccount = "jwt_token"
    private static let legacyDefaultsKey = "jwt_token"

    static func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        } else {
            // Keychain unavailable (rare): keep the app working with the old storage.
            UserDefaults.standard.set(token, forKey: legacyDefaultsKey)
        }
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8),
           !token.isEmpty {
            return token
        }

        // Migration from the old UserDefaults storage
        if let legacyToken = UserDefaults.standard.string(forKey: legacyDefaultsKey),
           !legacyToken.isEmpty {
            saveToken(legacyToken)
            return legacyToken
        }

        return nil
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
    }
}
