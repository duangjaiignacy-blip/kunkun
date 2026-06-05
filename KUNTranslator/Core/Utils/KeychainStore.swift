import Foundation
import Security

struct KeychainStore {
    private let service = "com.kun.translator"

    func readAPIKey(account: String = "openai") throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KUNError.invalidResponse }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveAPIKey(_ apiKey: String, account: String = "openai") throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        if status != errSecItemNotFound { throw KUNError.invalidResponse }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
            throw KUNError.invalidResponse
        }
    }

    func deleteAPIKey(account: String = "openai") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
