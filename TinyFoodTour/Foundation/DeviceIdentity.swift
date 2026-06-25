import Foundation
import Security

// MARK: - DeviceIdentity
// Stable per-device UUID stored in Keychain — survives app reinstalls.
// Used as `client_id` for guest reactions and walk-together participation,
// mirroring the web app's localStorage `client_id` pattern.

enum DeviceIdentity {
    private static let service = TFTConfig.appBundleID
    private static let account = "device_client_id"

    /// Returns the stable client ID, creating and persisting one on first call.
    static var clientId: String {
        if let existing = load() { return existing }
        let new = UUID().uuidString
        save(new)
        return new
    }

    private static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func save(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Stores guest share tokens for claiming on sign-in (mirrors web localStorage array).
    static func addGuestShareToken(_ token: String) {
        var tokens = guestShareTokens
        guard !tokens.contains(token) else { return }
        tokens.append(token)
        saveTokenList(tokens)
    }

    static var guestShareTokens: [String] {
        let account = "guest_share_tokens"
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arr
    }

    static func clearGuestShareTokens() { saveTokenList([]) }

    private static func saveTokenList(_ tokens: [String]) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let account = "guest_share_tokens"
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
