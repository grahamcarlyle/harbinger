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
        case unauthorized
        case notFound
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
            case .unauthorized:
                return "Unauthorized access"
            case .notFound:
                return "Resource not found"
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
        // Use type=owner to get only repositories owned by the authenticated user (not organization repos)
        fetchAllRepositories(url: "\(baseURL)/user/repos?type=owner", completion: completion)
    }
    
    public func getUserOrganizations(completion: @escaping (Result<[Organization], GitHubError>) -> Void) {
        guard let accessToken = GitHubOAuthConfig.accessToken else {
            completion(.failure(.noAccessToken))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/user/orgs") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔧 GitHubClient: Fetching user organizations")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            print("🔧 GitHubClient: User organizations response received")
            self?.handleOrganizationsResponse(data: data, response: response, error: error, completion: completion)
        }
        
        print("🔧 GitHubClient: Starting user organizations request task")
        task.resume()
        print("🔧 GitHubClient: User organizations request task started")
    }
    
    public func getOrganizationRepositories(org: String, completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        fetchAllRepositories(url: "\(baseURL)/orgs/\(org)/repos", completion: completion)
    }
    
    public func getRepository(owner: String, repo: String, completion: @escaping (Result<Repository, GitHubError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authorization if available (for private repos), but also allow unauthenticated requests for public repos
        if let accessToken = GitHubOAuthConfig.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔧 GitHubClient: Fetching repository \(owner)/\(repo)")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleRepositoryResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    // MARK: - Public Repository Search
    
    public func searchPublicRepositories(query: String, sort: String = "updated", order: String = "desc", page: Int = 1, perPage: Int = 30, completion: @escaping (Result<RepositorySearchResponse, GitHubError>) -> Void) {
        // Construct search query URL
        var components = URLComponents(string: "\(baseURL)/search/repositories")!
        
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authorization if available for higher rate limits
        if let accessToken = GitHubOAuthConfig.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔧 GitHubClient: Searching public repositories for query: \(query)")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleSearchResponse(data: data, response: response, error: error, completion: completion)
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
    
    private func fetchAllRepositories(url: String, page: Int = 1, allRepos: [Repository] = [], completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        guard let accessToken = GitHubOAuthConfig.accessToken else {
            completion(.failure(.noAccessToken))
            return
        }
        
        let separator = url.contains("?") ? "&" : "?"
        guard let requestUrl = URL(string: "\(url)\(separator)per_page=100&sort=updated&page=\(page)") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbinger/1.0", forHTTPHeaderField: "User-Agent")
        
        print("🔧 GitHubClient: Fetching repositories page \(page) from \(url)")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            print("🔧 GitHubClient: Repositories page \(page) response received")
            
            if let error = error {
                print("❌ GitHubClient: Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ GitHubClient: Invalid response")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ GitHubClient: HTTP error \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
                }
                return
            }
            
            guard let data = data else {
                print("❌ GitHubClient: No data received")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let repositories = try decoder.decode([Repository].self, from: data)
                print("✅ GitHubClient: Successfully decoded \(repositories.count) repositories on page \(page)")
                
                let updatedRepos = allRepos + repositories
                
                // If we got fewer than 100 repos, we've reached the end
                if repositories.count < 100 {
                    print("📊 GitHubClient: Finished pagination. Total repositories: \(updatedRepos.count)")
                    DispatchQueue.main.async {
                        completion(.success(updatedRepos))
                    }
                } else {
                    // Fetch next page
                    self?.fetchAllRepositories(url: url, page: page + 1, allRepos: updatedRepos, completion: completion)
                }
                
            } catch {
                print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
            }
        }
        
        task.resume()
    }
    
    private func handleOrganizationsResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Organization], GitHubError>) -> Void) {
        print("🔧 GitHubClient: handleOrganizationsResponse called")
        
        if let error = error {
            print("❌ GitHubClient: Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.networkError(error.localizedDescription)))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GitHubClient: Invalid response")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            print("❌ GitHubClient: Authentication failed")
            DispatchQueue.main.async {
                completion(.failure(.authenticationError))
            }
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                print("❌ GitHubClient: Rate limit exceeded")
                DispatchQueue.main.async {
                    completion(.failure(.rateLimitExceeded))
                }
            } else {
                print("❌ GitHubClient: Forbidden")
                DispatchQueue.main.async {
                    completion(.failure(.authenticationError))
                }
            }
            return
        default:
            print("❌ GitHubClient: HTTP error \(httpResponse.statusCode)")
            DispatchQueue.main.async {
                completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            }
            return
        }
        
        guard let data = data else {
            print("❌ GitHubClient: No data received")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let organizations = try decoder.decode([Organization].self, from: data)
            print("✅ GitHubClient: Successfully decoded \(organizations.count) organizations")
            DispatchQueue.main.async {
                completion(.success(organizations))
            }
        } catch {
            print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
    }
    
    private func handleRepositoriesResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        print("🔧 GitHubClient: handleRepositoriesResponse called")
        
        if let error = error {
            print("❌ GitHubClient: Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.networkError(error.localizedDescription)))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GitHubClient: Invalid response")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            print("❌ GitHubClient: Authentication failed")
            DispatchQueue.main.async {
                completion(.failure(.authenticationError))
            }
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                print("❌ GitHubClient: Rate limit exceeded")
                DispatchQueue.main.async {
                    completion(.failure(.rateLimitExceeded))
                }
            } else {
                print("❌ GitHubClient: Forbidden")
                DispatchQueue.main.async {
                    completion(.failure(.authenticationError))
                }
            }
            return
        default:
            print("❌ GitHubClient: HTTP error \(httpResponse.statusCode)")
            DispatchQueue.main.async {
                completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            }
            return
        }
        
        guard let data = data else {
            print("❌ GitHubClient: No data received")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let repositories = try decoder.decode([Repository].self, from: data)
            print("✅ GitHubClient: Successfully decoded \(repositories.count) repositories")
            DispatchQueue.main.async {
                completion(.success(repositories))
            }
        } catch {
            print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
    }
    
    private func handleRepositoryResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<Repository, GitHubError>) -> Void) {
        
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
            completion(.failure(.unauthorized))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                print("❌ GitHubClient: Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                print("❌ GitHubClient: Forbidden")
                completion(.failure(.unauthorized))
            }
            return
        case 404:
            print("❌ GitHubClient: Repository not found")
            completion(.failure(.notFound))
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
            let repository = try decoder.decode(Repository.self, from: data)
            print("✅ GitHubClient: Successfully decoded repository \(repository.fullName)")
            completion(.success(repository))
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
    
    private func handleSearchResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<RepositorySearchResponse, GitHubError>) -> Void) {
        
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
        case 422:
            print("❌ GitHubClient: Invalid search query")
            completion(.failure(.apiError("Invalid search query")))
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
        
        print("🔧 GitHubClient: Received \(data.count) bytes of search data")
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let searchResponse = try decoder.decode(RepositorySearchResponse.self, from: data)
            print("✅ GitHubClient: Successfully decoded \(searchResponse.items.count) repositories from search")
            completion(.success(searchResponse))
        } catch {
            print("❌ GitHubClient: Decoding error: \(error.localizedDescription)")
            
            // Try to provide more specific error information
            if let decodingError = error as? DecodingError {
                print("❌ GitHubClient: Detailed decoding error: \(decodingError)")
            }
            
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