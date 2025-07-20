import Foundation
import Cocoa

class AuthManager {
    
    // MARK: - Properties
    
    private var deviceCode: String?
    private var userCode: String?
    private var verificationURI: String?
    private var expiresAt: Date?
    
    // MARK: - Errors
    
    enum AuthError: Error, LocalizedError {
        case networkError(String)
        case invalidResponse
        case authorizationPending
        case slowDown
        case accessDenied
        case expiredToken
        case deviceFlowNotEnabled
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .networkError(let message):
                return "Network error: \(message)"
            case .invalidResponse:
                return "Invalid response from GitHub"
            case .authorizationPending:
                return "Authorization pending"
            case .slowDown:
                return "Polling too fast"
            case .accessDenied:
                return "Access denied by user"
            case .expiredToken:
                return "Device code expired"
            case .deviceFlowNotEnabled:
                return "Device flow not enabled for this app"
            case .unknownError(let message):
                return "Unknown error: \(message)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func initiateDeviceFlow(completion: @escaping (Result<(userCode: String, verificationURI: String), AuthError>) -> Void) {
        StatusBarDebugger.shared.log(.network, "AuthManager: Initiating device flow")
        
        // Check if we have a valid Client ID
        guard !GitHubOAuthConfig.clientID.isEmpty else {
            completion(.failure(.deviceFlowNotEnabled))
            return
        }
        
        // Prepare request
        let url = URL(string: GitHubOAuthConfig.baseURL + GitHubOAuthConfig.deviceCodeURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Request body
        let scopeString = GitHubOAuthConfig.scopes.joined(separator: " ")
        let bodyString = "client_id=\(GitHubOAuthConfig.clientID)&scope=\(scopeString)"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔧 AuthManager: Sending device code request...")
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleDeviceCodeResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    func exchangeDeviceCodeForToken(completion: @escaping (Result<String, AuthError>) -> Void) {
        guard let deviceCode = deviceCode else {
            completion(.failure(.invalidResponse))
            return
        }
        
        StatusBarDebugger.shared.log(.network, "AuthManager: Exchanging device code for token")
        
        // Check if expired
        if let expiresAt = expiresAt, Date() > expiresAt {
            StatusBarDebugger.shared.log(.error, "AuthManager: Device code expired")
            completion(.failure(.expiredToken))
            return
        }
        
        // Make single exchange request
        makeTokenExchangeRequest(completion: completion)
    }
    
    func cancelAuthentication() {
        StatusBarDebugger.shared.log(.network, "AuthManager: Canceling authentication")
        
        deviceCode = nil
        userCode = nil
        verificationURI = nil
        expiresAt = nil
    }
    
    // MARK: - Private Methods
    
    private func handleDeviceCodeResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<(userCode: String, verificationURI: String), AuthError>) -> Void) {
        
        if let error = error {
            print("❌ AuthManager: Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let data = data else {
            print("❌ AuthManager: No data received")
            completion(.failure(.invalidResponse))
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            if let errorCode = json?["error"] as? String {
                print("❌ AuthManager: GitHub error: \(errorCode)")
                let error = mapGitHubError(errorCode)
                completion(.failure(error))
                return
            }
            
            guard let deviceCode = json?["device_code"] as? String,
                  let userCode = json?["user_code"] as? String,
                  let verificationURI = json?["verification_uri"] as? String,
                  let expiresIn = json?["expires_in"] as? Int else {
                print("❌ AuthManager: Invalid response format")
                completion(.failure(.invalidResponse))
                return
            }
            
            // Store values
            self.deviceCode = deviceCode
            self.userCode = userCode
            self.verificationURI = verificationURI
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
            
            print("✅ AuthManager: Device code received")
            print("🔧 AuthManager: User code: \(userCode)")
            print("🔧 AuthManager: Verification URI: \(verificationURI)")
            
            completion(.success((userCode: userCode, verificationURI: verificationURI)))
            
        } catch {
            print("❌ AuthManager: JSON parsing error: \(error.localizedDescription)")
            completion(.failure(.invalidResponse))
        }
    }
    
    private func makeTokenExchangeRequest(completion: @escaping (Result<String, AuthError>) -> Void) {
        guard let deviceCode = deviceCode else {
            completion(.failure(.invalidResponse))
            return
        }
        
        // Prepare request
        let url = URL(string: GitHubOAuthConfig.baseURL + GitHubOAuthConfig.accessTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Request body
        let bodyString = "client_id=\(GitHubOAuthConfig.clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        request.httpBody = bodyString.data(using: .utf8)
        
        StatusBarDebugger.shared.log(.network, "AuthManager: Making token exchange request")
        
        // Make request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            StatusBarDebugger.shared.log(.network, "AuthManager: Token exchange response received")
            self?.handleTokenResponse(data: data, response: response, error: error, completion: completion)
        }
        
        StatusBarDebugger.shared.log(.network, "AuthManager: Starting token exchange task")
        task.resume()
        StatusBarDebugger.shared.log(.network, "AuthManager: Token exchange task resumed")
    }
    
    private func handleTokenResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<String, AuthError>) -> Void) {
        StatusBarDebugger.shared.log(.network, "AuthManager: handleTokenResponse called")
        
        if let error = error {
            StatusBarDebugger.shared.log(.error, "AuthManager: Token request error", context: ["error": error.localizedDescription])
            DispatchQueue.main.async {
                completion(.failure(.networkError(error.localizedDescription)))
            }
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "AuthManager: No token data received")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        StatusBarDebugger.shared.log(.network, "AuthManager: Received token response data", context: ["dataSize": data.count])
        
        // Log the raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            StatusBarDebugger.shared.log(.network, "AuthManager: Raw response", context: ["response": responseString])
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            StatusBarDebugger.shared.log(.network, "AuthManager: JSON parsed successfully", context: ["keys": json?.keys.sorted().joined(separator: ",") ?? "none"])
            
            if let errorCode = json?["error"] as? String {
                let authError = mapGitHubError(errorCode)
                StatusBarDebugger.shared.log(.error, "AuthManager: GitHub error", context: ["error": errorCode])
                DispatchQueue.main.async {
                    completion(.failure(authError))
                }
                return
            }
            
            guard let accessToken = json?["access_token"] as? String else {
                StatusBarDebugger.shared.log(.error, "AuthManager: No access token in response", context: ["availableKeys": json?.keys.sorted().joined(separator: ",") ?? "none"])
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            // Success! Store token and complete
            StatusBarDebugger.shared.log(.network, "AuthManager: Access token received successfully!", context: ["tokenLength": accessToken.count])
            GitHubOAuthConfig.setAccessToken(accessToken)
            
            DispatchQueue.main.async {
                completion(.success(accessToken))
            }
            
        } catch {
            StatusBarDebugger.shared.log(.error, "AuthManager: Token JSON parsing error", context: ["error": error.localizedDescription])
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
        }
    }
    
    private func mapGitHubError(_ errorCode: String) -> AuthError {
        switch errorCode {
        case "authorization_pending":
            return .authorizationPending
        case "slow_down":
            return .slowDown
        case "access_denied":
            return .accessDenied
        case "expired_token":
            return .expiredToken
        case "unsupported_grant_type":
            return .deviceFlowNotEnabled
        default:
            return .unknownError(errorCode)
        }
    }
}