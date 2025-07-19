import Foundation
import Cocoa

class AuthManager {
    
    // MARK: - Properties
    
    private var deviceCode: String?
    private var userCode: String?
    private var verificationURI: String?
    private var pollingInterval: Int = 5
    private var pollingTimer: Timer?
    private var expiresAt: Date?
    
    // Completion handlers
    private var authCompletionHandler: ((Result<String, AuthError>) -> Void)?
    
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
        print("🔧 AuthManager: Initiating device flow...")
        
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
    
    func pollForAccessToken(completion: @escaping (Result<String, AuthError>) -> Void) {
        guard let deviceCode = deviceCode else {
            completion(.failure(.invalidResponse))
            return
        }
        
        print("🔧 AuthManager: Starting token polling...")
        
        // Store completion handler
        authCompletionHandler = completion
        
        // Start polling
        startPolling()
    }
    
    func cancelAuthentication() {
        print("🔧 AuthManager: Canceling authentication...")
        
        pollingTimer?.invalidate()
        pollingTimer = nil
        deviceCode = nil
        userCode = nil
        verificationURI = nil
        authCompletionHandler = nil
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
            
            if let interval = json?["interval"] as? Int {
                self.pollingInterval = interval
            }
            
            print("✅ AuthManager: Device code received")
            print("🔧 AuthManager: User code: \(userCode)")
            print("🔧 AuthManager: Verification URI: \(verificationURI)")
            
            completion(.success((userCode: userCode, verificationURI: verificationURI)))
            
        } catch {
            print("❌ AuthManager: JSON parsing error: \(error.localizedDescription)")
            completion(.failure(.invalidResponse))
        }
    }
    
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pollingInterval), repeats: true) { [weak self] _ in
            self?.pollForToken()
        }
    }
    
    private func pollForToken() {
        guard let deviceCode = deviceCode,
              let expiresAt = expiresAt else {
            authCompletionHandler?(.failure(.invalidResponse))
            return
        }
        
        // Check if expired
        if Date() > expiresAt {
            print("❌ AuthManager: Device code expired")
            pollingTimer?.invalidate()
            authCompletionHandler?(.failure(.expiredToken))
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
        
        print("🔧 AuthManager: Polling for access token...")
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleTokenResponse(data: data, response: response, error: error)
            }
        }.resume()
    }
    
    private func handleTokenResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            print("❌ AuthManager: Token request error: \(error.localizedDescription)")
            authCompletionHandler?(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let data = data else {
            print("❌ AuthManager: No token data received")
            authCompletionHandler?(.failure(.invalidResponse))
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            if let errorCode = json?["error"] as? String {
                let error = mapGitHubError(errorCode)
                
                // Handle specific polling errors
                switch error {
                case .authorizationPending:
                    print("🔧 AuthManager: Authorization pending, continuing to poll...")
                    return // Continue polling
                case .slowDown:
                    print("🔧 AuthManager: Slowing down polling...")
                    pollingInterval += 5
                    return // Continue polling
                default:
                    print("❌ AuthManager: GitHub error: \(errorCode)")
                    pollingTimer?.invalidate()
                    authCompletionHandler?(.failure(error))
                    return
                }
            }
            
            guard let accessToken = json?["access_token"] as? String else {
                print("❌ AuthManager: No access token in response")
                authCompletionHandler?(.failure(.invalidResponse))
                return
            }
            
            // Success! Store token and complete
            print("✅ AuthManager: Access token received!")
            GitHubOAuthConfig.setAccessToken(accessToken)
            
            pollingTimer?.invalidate()
            authCompletionHandler?(.success(accessToken))
            
        } catch {
            print("❌ AuthManager: Token JSON parsing error: \(error.localizedDescription)")
            authCompletionHandler?(.failure(.invalidResponse))
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