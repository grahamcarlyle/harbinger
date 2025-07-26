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
    static let scopes = ["repo"]
    
    // Device Flow configuration
    static let pollingInterval = 5 // seconds
    static let maxPollingAttempts = 120 // 10 minutes max
    
    // Access token (stored in Keychain)
    static var accessToken: String? {
        let token = KeychainHelper.retrievePassword(service: "Harbinger", account: "GitHubAccessToken")
        StatusBarDebugger.shared.log(.lifecycle, "Access token retrieved from Keychain", 
                                   context: ["hasToken": token != nil, "tokenLength": token?.count ?? 0])
        return token
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
        StatusBarDebugger.shared.log(.lifecycle, "Storing access token in Keychain", 
                                   context: ["tokenLength": token.count])
        KeychainHelper.storePassword(service: "Harbinger", account: "GitHubAccessToken", password: token)
        UserDefaults.standard.set(Date(), forKey: "GitHubTokenCreated")
        
        // Verify storage worked
        let retrievedToken = KeychainHelper.retrievePassword(service: "Harbinger", account: "GitHubAccessToken")
        StatusBarDebugger.shared.log(.lifecycle, "Token storage verification", 
                                   context: ["stored": retrievedToken != nil, "matches": retrievedToken == token])
    }
    
    static func clearCredentials() {
        StatusBarDebugger.shared.log(.lifecycle, "Clearing credentials from Keychain")
        KeychainHelper.deletePassword(service: "Harbinger", account: "GitHubAccessToken")
        UserDefaults.standard.removeObject(forKey: "GitHubTokenCreated")
    }
    
    static var isConfigured: Bool {
        let token = accessToken
        let configured = token != nil && !token!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        StatusBarDebugger.shared.log(.lifecycle, "Checking if GitHub is configured", 
                                   context: ["configured": configured, "hasToken": token != nil])
        return configured
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
        StatusBarDebugger.shared.log(.lifecycle, "KeychainHelper: Storing password", 
                                   context: ["service": service, "account": account, "passwordLength": password.count])
        
        let data = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete any existing item first
        let deleteStatus = SecItemDelete(query as CFDictionary)
        StatusBarDebugger.shared.log(.lifecycle, "KeychainHelper: Delete existing item", 
                                   context: ["status": deleteStatus, "statusDescription": SecCopyErrorMessageString(deleteStatus, nil) ?? "Unknown"])
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            StatusBarDebugger.shared.log(.error, "KeychainHelper: Failed to store password", 
                                       context: ["status": status, "statusDescription": SecCopyErrorMessageString(status, nil) ?? "Unknown"])
        } else {
            StatusBarDebugger.shared.log(.lifecycle, "KeychainHelper: Password stored successfully")
        }
    }
    
    static func retrievePassword(service: String, account: String) -> String? {
        StatusBarDebugger.shared.log(.lifecycle, "KeychainHelper: Retrieving password", 
                                   context: ["service": service, "account": account])
        
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
                let password = String(data: data, encoding: .utf8)
                StatusBarDebugger.shared.log(.lifecycle, "KeychainHelper: Password retrieved successfully", 
                                           context: ["passwordLength": password?.count ?? 0])
                return password
            } else {
                StatusBarDebugger.shared.log(.error, "KeychainHelper: Data conversion failed")
            }
        } else {
            StatusBarDebugger.shared.log(.lifecycle, "KeychainHelper: Password retrieval failed", 
                                       context: ["status": status, "statusDescription": SecCopyErrorMessageString(status, nil) ?? "Unknown"])
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