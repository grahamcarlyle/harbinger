import Foundation

public class GitHubClient {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL = GitHubOAuthConfig.apiBaseURL
    
    // MARK: - Initialization
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Errors
    
    public enum GitHubError: Error, LocalizedError {
        case noAccessToken
        case invalidURL
        case networkError(String)
        case authenticationError
        case rateLimitExceeded
        case invalidResponse
        case apiError(String)
        case decodingError(String)
        
        public var errorDescription: String? {
            switch self {
            case .noAccessToken:
                return "No access token available"
            case .invalidURL:
                return "Invalid URL"
            case .networkError(let message):
                return "Network error: \(message)"
            case .authenticationError:
                return "Authentication failed"
            case .rateLimitExceeded:
                return "Rate limit exceeded"
            case .invalidResponse:
                return "Invalid response from GitHub"
            case .apiError(let message):
                return "API error: \(message)"
            case .decodingError(let message):
                return "Decoding error: \(message)"
            }
        }
    }
    
    // MARK: - API Methods
    
    public func getWorkflowRuns(owner: String, repo: String, completion: @escaping (Result<WorkflowRunsResponse, GitHubError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/runs") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add auth header if token is available
        if let accessToken = GitHubOAuthConfig.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔧 GitHubClient: Fetching workflow runs for \(owner)/\(repo) (authenticated)")
        } else {
            print("🔧 GitHubClient: Fetching workflow runs for \(owner)/\(repo) (unauthenticated - public only)")
        }
        
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleWorkflowRunsResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    public func getRepositories(completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        guard let accessToken = GitHubOAuthConfig.accessToken else {
            completion(.failure(.noAccessToken))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/user/repos") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔧 GitHubClient: Fetching user repositories")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleRepositoriesResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    public func getWorkflows(owner: String, repo: String, completion: @escaping (Result<WorkflowsResponse, GitHubError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/workflows") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add auth header if token is available
        if let accessToken = GitHubOAuthConfig.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("🔧 GitHubClient: Fetching workflows for \(owner)/\(repo) (authenticated)")
        } else {
            print("🔧 GitHubClient: Fetching workflows for \(owner)/\(repo) (unauthenticated - public only)")
        }
        
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleWorkflowsResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    // MARK: - Response Handlers
    
    private func handleWorkflowRunsResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<WorkflowRunsResponse, GitHubError>) -> Void) {
        
        if let error = error {
            print("❌ GitHubClient: Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GitHubClient: Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            print("❌ GitHubClient: Authentication failed")
            completion(.failure(.authenticationError))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                print("❌ GitHubClient: Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                print("❌ GitHubClient: Forbidden")
                completion(.failure(.authenticationError))
            }
            return
        case 404:
            print("❌ GitHubClient: Repository not found")
            completion(.failure(.apiError("Repository not found")))
            return
        default:
            print("❌ GitHubClient: HTTP error \(httpResponse.statusCode)")
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            print("❌ GitHubClient: No data received - HTTP \(httpResponse.statusCode)")
            print("❌ GitHubClient: Response headers: \(httpResponse.allHeaderFields)")
            completion(.failure(.invalidResponse))
            return
        }
        
        print("🔧 GitHubClient: Received \(data.count) bytes of data")
        
        // Debug: Print first 200 characters of response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = String(responseString.prefix(200))
            print("🔧 GitHubClient: Response preview: \(preview)")
        }
        
        do {
            let decoder = JSONDecoder()
            // Make the decoder more tolerant of missing fields
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let workflowRuns = try decoder.decode(WorkflowRunsResponse.self, from: data)
            print("✅ GitHubClient: Successfully decoded \(workflowRuns.workflowRuns.count) workflow runs")
            completion(.success(workflowRuns))
        } catch {
            print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
            
            // Try to provide more specific error information
            if let decodingError = error as? DecodingError {
                print("❌ GitHubClient: Detailed decoding error: \(decodingError)")
            }
            
            completion(.failure(.decodingError(error.localizedDescription)))
        }
    }
    
    private func handleRepositoriesResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        
        if let error = error {
            print("❌ GitHubClient: Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GitHubClient: Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            print("❌ GitHubClient: Authentication failed")
            completion(.failure(.authenticationError))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                print("❌ GitHubClient: Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                print("❌ GitHubClient: Forbidden")
                completion(.failure(.authenticationError))
            }
            return
        default:
            print("❌ GitHubClient: HTTP error \(httpResponse.statusCode)")
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            print("❌ GitHubClient: No data received")
            completion(.failure(.invalidResponse))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let repositories = try decoder.decode([Repository].self, from: data)
            print("✅ GitHubClient: Successfully decoded \(repositories.count) repositories")
            completion(.success(repositories))
        } catch {
            print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
            completion(.failure(.decodingError(error.localizedDescription)))
        }
    }
    
    private func handleWorkflowsResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<WorkflowsResponse, GitHubError>) -> Void) {
        
        if let error = error {
            print("❌ GitHubClient: Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GitHubClient: Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            print("❌ GitHubClient: Authentication failed")
            completion(.failure(.authenticationError))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                print("❌ GitHubClient: Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                print("❌ GitHubClient: Forbidden")
                completion(.failure(.authenticationError))
            }
            return
        case 404:
            print("❌ GitHubClient: Repository not found")
            completion(.failure(.apiError("Repository not found")))
            return
        default:
            print("❌ GitHubClient: HTTP error \(httpResponse.statusCode)")
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            print("❌ GitHubClient: No data received")
            completion(.failure(.invalidResponse))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let workflows = try decoder.decode(WorkflowsResponse.self, from: data)
            print("✅ GitHubClient: Successfully decoded \(workflows.workflows.count) workflows")
            completion(.success(workflows))
        } catch {
            print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
            completion(.failure(.decodingError(error.localizedDescription)))
        }
    }
    
    // MARK: - Helper Methods
    
    public func isAuthenticated() -> Bool {
        return GitHubOAuthConfig.isConfigured
    }
    
    public func clearAuthentication() {
        GitHubOAuthConfig.clearCredentials()
    }
}