import Foundation
import Security

struct GitHubOAuthConfig {
    // OAuth App configuration - Client ID is public, no client secret needed for Device Flow
    static let clientID = "Ov23li6QFftczn50i92O" // Replace with your OAuth App Client ID
    
    // GitHub OAuth Device Flow endpoints
    static let baseURL = "https://github.com"
    static let deviceCodeURL = "/login/device/code"
    static let accessTokenURL = "/login/oauth/access_token"
    static let apiBaseURL = "https://api.github.com"
    
    // Required scopes for accessing repositories and workflows
    static let scopes = ["repo", "workflow"]
    
    // Device Flow configuration
    static let pollingInterval = 5 // seconds
    static let maxPollingAttempts = 120 // 10 minutes max
    
    // Access token (stored in Keychain)
    static var accessToken: String? {
        return KeychainHelper.retrievePassword(service: "Harbinger", account: "GitHubAccessToken")
    }
    
    // Token expiration tracking (GitHub tokens don't expire but can be revoked)
    static var tokenCreatedAt: Date? {
        if let timestamp = UserDefaults.standard.object(forKey: "GitHubTokenCreated") as? Date {
            return timestamp
        }
        return nil
    }
    
    // Helper methods for credential management
    static func setAccessToken(_ token: String) {
        KeychainHelper.storePassword(service: "Harbinger", account: "GitHubAccessToken", password: token)
        UserDefaults.standard.set(Date(), forKey: "GitHubTokenCreated")
    }
    
    static func clearCredentials() {
        KeychainHelper.deletePassword(service: "Harbinger", account: "GitHubAccessToken")
        UserDefaults.standard.removeObject(forKey: "GitHubTokenCreated")
    }
    
    static var isConfigured: Bool {
        return accessToken != nil && !accessToken!.isEmpty
    }
    
    // Device Flow response models
    struct DeviceCodeResponse {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let verificationUriComplete: String
        let expiresIn: Int
        let interval: Int
    }
    
    struct AccessTokenResponse {
        let accessToken: String
        let tokenType: String
        let scope: String
    }
    
    struct ErrorResponse {
        let error: String
        let errorDescription: String?
    }
}

// MARK: - Keychain Helper for secure storage
class KeychainHelper {
    
    static func storePassword(service: String, account: String, password: String) {
        let data = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Failed to store password in keychain: \(status)")
        }
    }
    
    static func retrievePassword(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    static func deletePassword(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}