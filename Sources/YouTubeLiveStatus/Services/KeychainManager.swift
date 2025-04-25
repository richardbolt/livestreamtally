import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.youtubelivestatus.app"
    private let account = "youtube_api_key"
    
    func saveAPIKey(_ apiKey: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        return status == errSecSuccess
    }
    
    func retrieveAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let retrievedData = dataTypeRef as? Data,
           let value = String(data: retrievedData, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case retrieveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case unexpectedData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save API key to Keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve API key from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete API key from Keychain: \(status)"
        case .unexpectedData:
            return "Retrieved data was in unexpected format"
        }
    }
} 