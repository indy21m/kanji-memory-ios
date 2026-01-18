import Foundation
import Security

/// Helper for securely storing sensitive data in iOS Keychain
struct KeychainHelper {
    // Use the app's bundle ID as the keychain service name
    private static let serviceName = "com.marioscian.penguinsensei"

    private enum Keys {
        static let authToken = "authToken"
        static let userData = "userData"
        static let wanikaniApiKey = "wanikaniApiKey"
    }

    // MARK: - Auth Token
    static func saveAuthToken(_ token: String) {
        save(key: Keys.authToken, data: Data(token.utf8))
    }

    static func getAuthToken() -> String? {
        guard let data = load(key: Keys.authToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAuthToken() {
        delete(key: Keys.authToken)
    }

    // MARK: - User Data
    static func saveUserData(_ data: Data) {
        save(key: Keys.userData, data: data)
    }

    static func getUserData() -> Data? {
        return load(key: Keys.userData)
    }

    static func deleteUserData() {
        delete(key: Keys.userData)
    }

    // MARK: - WaniKani API Key
    static func saveWaniKaniApiKey(_ key: String) {
        save(key: Keys.wanikaniApiKey, data: Data(key.utf8))
    }

    static func getWaniKaniApiKey() -> String? {
        guard let data = load(key: Keys.wanikaniApiKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteWaniKaniApiKey() {
        delete(key: Keys.wanikaniApiKey)
    }

    // MARK: - Generic Keychain Operations
    private static func save(key: String, data: Data) {
        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Keychain save error for \(key): \(status)")
        }
    }

    private static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        } else if status != errSecItemNotFound {
            print("Keychain load error for \(key): \(status)")
        }

        return nil
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain delete error for \(key): \(status)")
        }
    }

    // MARK: - Clear All
    static func clearAll() {
        deleteAuthToken()
        deleteUserData()
        deleteWaniKaniApiKey()
    }
}
