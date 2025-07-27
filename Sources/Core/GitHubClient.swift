import Foundation

public class GitHubClient {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL = GitHubOAuthConfig.apiBaseURL
    private let userDefaults = UserDefaults.standard
    
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
            StatusBarDebugger.shared.log(.network, "GitHubClient: Fetching workflow runs (authenticated)", context: ["owner": owner, "repo": repo])
        } else {
            StatusBarDebugger.shared.log(.network, "GitHubClient: Fetching workflow runs (unauthenticated)", context: ["owner": owner, "repo": repo])
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
        let cacheKey = "CachedPersonalRepositories"
        
        // Try to load from cache first
        if let cachedRepos = loadRepositoriesFromCache(key: cacheKey) {
            StatusBarDebugger.shared.log(.network, "Loaded personal repositories from cache", context: ["count": cachedRepos.count])
            completion(.success(cachedRepos))
            return
        }
        
        StatusBarDebugger.shared.log(.network, "Cache miss, fetching personal repositories from API")
        // Use type=owner to get only repositories owned by the authenticated user (not organization repos)
        fetchAllRepositories(url: "\(baseURL)/user/repos?type=owner") { [weak self] result in
            switch result {
            case .success(let repositories):
                self?.saveRepositoriesToCache(repositories: repositories, key: cacheKey)
                completion(.success(repositories))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func getUserOrganizations(completion: @escaping (Result<[Organization], GitHubError>) -> Void) {
        let cacheKey = "CachedUserOrganizations"
        
        // Try to load from cache first
        if let cachedOrgs = loadOrganizationsFromCache(key: cacheKey) {
            StatusBarDebugger.shared.log(.network, "Loaded organizations from cache", context: ["count": cachedOrgs.count])
            completion(.success(cachedOrgs))
            return
        }
        
        StatusBarDebugger.shared.log(.network, "Cache miss, fetching organizations from API")
        
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
        
        StatusBarDebugger.shared.log(.network, "Fetching user organizations")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            StatusBarDebugger.shared.log(.network, "User organizations response received")
            self?.handleOrganizationsResponse(data: data, response: response, error: error) { result in
                switch result {
                case .success(let organizations):
                    self?.saveOrganizationsToCache(organizations: organizations, key: cacheKey)
                    completion(.success(organizations))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        StatusBarDebugger.shared.log(.network, "Starting user organizations request task")
        task.resume()
        StatusBarDebugger.shared.log(.network, "User organizations request task started")
    }
    
    public func getOrganizationRepositories(org: String, completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        let cacheKey = "CachedOrgRepositories_\(org)"
        
        // Try to load from cache first
        if let cachedRepos = loadRepositoriesFromCache(key: cacheKey) {
            StatusBarDebugger.shared.log(.network, "Loaded organization repositories from cache", context: ["org": org, "count": cachedRepos.count])
            completion(.success(cachedRepos))
            return
        }
        
        StatusBarDebugger.shared.log(.network, "Cache miss, fetching repositories for organization from API", context: ["org": org])
        fetchAllRepositories(url: "\(baseURL)/orgs/\(org)/repos") { [weak self] result in
            switch result {
            case .success(let repositories):
                self?.saveRepositoriesToCache(repositories: repositories, key: cacheKey)
                completion(.success(repositories))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
        
        StatusBarDebugger.shared.log(.network, "Fetching repository", context: ["owner": owner, "repo": repo])
        
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
        
        StatusBarDebugger.shared.log(.network, "Searching public repositories", context: ["query": query])
        
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
            StatusBarDebugger.shared.log(.network, "GitHubClient: Fetching workflows (authenticated)", context: ["owner": owner, "repo": repo])
        } else {
            StatusBarDebugger.shared.log(.network, "GitHubClient: Fetching workflows (unauthenticated)", context: ["owner": owner, "repo": repo])
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
            StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            StatusBarDebugger.shared.log(.error, "Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            StatusBarDebugger.shared.log(.error, "Authentication failed")
            completion(.failure(.authenticationError))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                StatusBarDebugger.shared.log(.error, "Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                StatusBarDebugger.shared.log(.error, "Forbidden")
                completion(.failure(.authenticationError))
            }
            return
        case 404:
            StatusBarDebugger.shared.log(.error, "Repository not found")
            completion(.failure(.apiError("Repository not found")))
            return
        default:
            StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "No data received", context: ["statusCode": httpResponse.statusCode])
            StatusBarDebugger.shared.log(.error, "Response headers", context: ["headers": httpResponse.allHeaderFields])
            completion(.failure(.invalidResponse))
            return
        }
        
        StatusBarDebugger.shared.log(.network, "GitHubClient: Received data", context: ["bytes": data.count])
        
        // Debug: Print first 200 characters of response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = String(responseString.prefix(200))
            StatusBarDebugger.shared.log(.network, "GitHubClient: Response preview", context: ["preview": preview])
        }
        
        do {
            let decoder = JSONDecoder()
            // Make the decoder more tolerant of missing fields
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let workflowRuns = try decoder.decode(WorkflowRunsResponse.self, from: data)
            StatusBarDebugger.shared.log(.network, "Successfully decoded workflow runs", context: ["count": workflowRuns.workflowRuns.count])
            completion(.success(workflowRuns))
        } catch {
            StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
            
            // Try to provide more specific error information
            if let decodingError = error as? DecodingError {
                StatusBarDebugger.shared.log(.error, "Detailed decoding error", context: ["error": String(describing: decodingError)])
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
        
        StatusBarDebugger.shared.log(.network, "Fetching repositories page", context: ["page": page, "url": url])
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            StatusBarDebugger.shared.log(.network, "Repositories page response received", context: ["page": page])
            
            if let error = error {
                StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                StatusBarDebugger.shared.log(.error, "Invalid response")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
                DispatchQueue.main.async {
                    completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
                }
                return
            }
            
            guard let data = data else {
                StatusBarDebugger.shared.log(.error, "No data received")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let repositories = try decoder.decode([Repository].self, from: data)
                StatusBarDebugger.shared.log(.network, "Successfully decoded repositories on page", context: ["count": repositories.count, "page": page])
                
                let updatedRepos = allRepos + repositories
                
                // If we got fewer than 100 repos, we've reached the end
                if repositories.count < 100 {
                    StatusBarDebugger.shared.log(.network, "Finished pagination", context: ["totalCount": updatedRepos.count])
                    DispatchQueue.main.async {
                        completion(.success(updatedRepos))
                    }
                } else {
                    // Fetch next page
                    self?.fetchAllRepositories(url: url, page: page + 1, allRepos: updatedRepos, completion: completion)
                }
                
            } catch {
                StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
            }
        }
        
        task.resume()
    }
    
    private func handleOrganizationsResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Organization], GitHubError>) -> Void) {
        StatusBarDebugger.shared.log(.network, "handleOrganizationsResponse called")
        
        if let error = error {
            StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
            DispatchQueue.main.async {
                completion(.failure(.networkError(error.localizedDescription)))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            StatusBarDebugger.shared.log(.error, "Invalid response")
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
            StatusBarDebugger.shared.log(.error, "Authentication failed")
            DispatchQueue.main.async {
                completion(.failure(.authenticationError))
            }
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                StatusBarDebugger.shared.log(.error, "Rate limit exceeded")
                DispatchQueue.main.async {
                    completion(.failure(.rateLimitExceeded))
                }
            } else {
                StatusBarDebugger.shared.log(.error, "Forbidden")
                DispatchQueue.main.async {
                    completion(.failure(.authenticationError))
                }
            }
            return
        default:
            StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
            DispatchQueue.main.async {
                completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            }
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "No data received")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let organizations = try decoder.decode([Organization].self, from: data)
            StatusBarDebugger.shared.log(.network, "Successfully decoded organizations", context: ["count": organizations.count])
            DispatchQueue.main.async {
                completion(.success(organizations))
            }
        } catch {
            StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
            DispatchQueue.main.async {
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
    }
    
    private func handleRepositoriesResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<[Repository], GitHubError>) -> Void) {
        StatusBarDebugger.shared.log(.network, "handleRepositoriesResponse called")
        
        if let error = error {
            StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
            DispatchQueue.main.async {
                completion(.failure(.networkError(error.localizedDescription)))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            StatusBarDebugger.shared.log(.error, "Invalid response")
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
            StatusBarDebugger.shared.log(.error, "Authentication failed")
            DispatchQueue.main.async {
                completion(.failure(.authenticationError))
            }
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                StatusBarDebugger.shared.log(.error, "Rate limit exceeded")
                DispatchQueue.main.async {
                    completion(.failure(.rateLimitExceeded))
                }
            } else {
                StatusBarDebugger.shared.log(.error, "Forbidden")
                DispatchQueue.main.async {
                    completion(.failure(.authenticationError))
                }
            }
            return
        default:
            StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
            DispatchQueue.main.async {
                completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            }
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "No data received")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let repositories = try decoder.decode([Repository].self, from: data)
            StatusBarDebugger.shared.log(.network, "Successfully decoded repositories", context: ["count": repositories.count])
            DispatchQueue.main.async {
                completion(.success(repositories))
            }
        } catch {
            StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
            DispatchQueue.main.async {
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
    }
    
    private func handleRepositoryResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<Repository, GitHubError>) -> Void) {
        
        if let error = error {
            StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            StatusBarDebugger.shared.log(.error, "Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            StatusBarDebugger.shared.log(.error, "Authentication failed")
            completion(.failure(.unauthorized))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                StatusBarDebugger.shared.log(.error, "Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                StatusBarDebugger.shared.log(.error, "Forbidden")
                completion(.failure(.unauthorized))
            }
            return
        case 404:
            StatusBarDebugger.shared.log(.error, "Repository not found")
            completion(.failure(.notFound))
            return
        default:
            StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "No data received")
            completion(.failure(.invalidResponse))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let repository = try decoder.decode(Repository.self, from: data)
            StatusBarDebugger.shared.log(.network, "Successfully decoded repository", context: ["fullName": repository.fullName])
            completion(.success(repository))
        } catch {
            StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
            completion(.failure(.decodingError(error.localizedDescription)))
        }
    }
    
    private func handleWorkflowsResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<WorkflowsResponse, GitHubError>) -> Void) {
        
        if let error = error {
            StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            StatusBarDebugger.shared.log(.error, "Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            StatusBarDebugger.shared.log(.error, "Authentication failed")
            completion(.failure(.authenticationError))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                StatusBarDebugger.shared.log(.error, "Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                StatusBarDebugger.shared.log(.error, "Forbidden")
                completion(.failure(.authenticationError))
            }
            return
        case 404:
            StatusBarDebugger.shared.log(.error, "Repository not found")
            completion(.failure(.apiError("Repository not found")))
            return
        default:
            StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "No data received")
            completion(.failure(.invalidResponse))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let workflows = try decoder.decode(WorkflowsResponse.self, from: data)
            StatusBarDebugger.shared.log(.network, "Successfully decoded workflows", context: ["count": workflows.workflows.count])
            completion(.success(workflows))
        } catch {
            StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
            completion(.failure(.decodingError(error.localizedDescription)))
        }
    }
    
    private func handleSearchResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<RepositorySearchResponse, GitHubError>) -> Void) {
        
        if let error = error {
            StatusBarDebugger.shared.log(.error, "Network error", context: ["description": error.localizedDescription])
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            StatusBarDebugger.shared.log(.error, "Invalid response")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            StatusBarDebugger.shared.log(.error, "Authentication failed")
            completion(.failure(.authenticationError))
            return
        case 403:
            if let rateLimitRemaining = httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String,
               rateLimitRemaining == "0" {
                StatusBarDebugger.shared.log(.error, "Rate limit exceeded")
                completion(.failure(.rateLimitExceeded))
            } else {
                StatusBarDebugger.shared.log(.error, "Forbidden")
                completion(.failure(.authenticationError))
            }
            return
        case 422:
            StatusBarDebugger.shared.log(.error, "Invalid search query")
            completion(.failure(.apiError("Invalid search query")))
            return
        default:
            StatusBarDebugger.shared.log(.error, "HTTP error", context: ["statusCode": httpResponse.statusCode])
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            StatusBarDebugger.shared.log(.error, "No data received")
            completion(.failure(.invalidResponse))
            return
        }
        
        StatusBarDebugger.shared.log(.network, "GitHubClient: Received search data", context: ["bytes": data.count])
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let searchResponse = try decoder.decode(RepositorySearchResponse.self, from: data)
            StatusBarDebugger.shared.log(.network, "Successfully decoded repositories from search", context: ["count": searchResponse.items.count])
            completion(.success(searchResponse))
        } catch {
            StatusBarDebugger.shared.log(.error, "Decoding error", context: ["description": error.localizedDescription])
            
            // Try to provide more specific error information
            if let decodingError = error as? DecodingError {
                StatusBarDebugger.shared.log(.error, "Detailed decoding error", context: ["error": String(describing: decodingError)])
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
        clearAllCaches()
    }
    
    // MARK: - Cache Management
    
    private func loadRepositoriesFromCache(key: String) -> [Repository]? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let cachedData = try JSONDecoder().decode(CachedRepositoryData.self, from: data)
            
            if cachedData.isExpired {
                userDefaults.removeObject(forKey: key)
                return nil
            }
            
            return cachedData.repositories
        } catch {
            StatusBarDebugger.shared.log(.warning, "Failed to load repository cache", context: ["key": key, "error": error.localizedDescription])
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }
    
    private func saveRepositoriesToCache(repositories: [Repository], key: String) {
        let cachedData = CachedRepositoryData(repositories: repositories)
        
        do {
            let data = try JSONEncoder().encode(cachedData)
            userDefaults.set(data, forKey: key)
            StatusBarDebugger.shared.log(.network, "Saved repositories to cache", context: ["count": repositories.count, "key": key])
        } catch {
            StatusBarDebugger.shared.log(.warning, "Failed to save repository cache", context: ["key": key, "error": error.localizedDescription])
        }
    }
    
    private func loadOrganizationsFromCache(key: String) -> [Organization]? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            let cachedData = try JSONDecoder().decode(CachedOrganizationData.self, from: data)
            
            if cachedData.isExpired {
                userDefaults.removeObject(forKey: key)
                return nil
            }
            
            return cachedData.organizations
        } catch {
            StatusBarDebugger.shared.log(.warning, "Failed to load organization cache", context: ["key": key, "error": error.localizedDescription])
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }
    
    private func saveOrganizationsToCache(organizations: [Organization], key: String) {
        let cachedData = CachedOrganizationData(organizations: organizations)
        
        do {
            let data = try JSONEncoder().encode(cachedData)
            userDefaults.set(data, forKey: key)
            StatusBarDebugger.shared.log(.network, "Saved organizations to cache", context: ["count": organizations.count, "key": key])
        } catch {
            StatusBarDebugger.shared.log(.warning, "Failed to save organization cache", context: ["key": key, "error": error.localizedDescription])
        }
    }
    
    public func clearAllCaches() {
        let keysToRemove = [
            "CachedPersonalRepositories",
            "CachedUserOrganizations"
        ]
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        // Clear organization-specific repository caches
        let allKeys = Array(userDefaults.dictionaryRepresentation().keys)
        for key in allKeys {
            if key.hasPrefix("CachedOrgRepositories_") {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        StatusBarDebugger.shared.log(.network, "Cleared all repository and organization caches")
    }
}