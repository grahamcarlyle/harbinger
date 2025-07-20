import Foundation

// MARK: - Data Models

public struct MonitoredRepository: Codable, Equatable {
    public let owner: String
    public let name: String
    public let fullName: String
    public let isPrivate: Bool
    public let url: String
    
    public init(owner: String, name: String, fullName: String, isPrivate: Bool, url: String) {
        self.owner = owner
        self.name = name
        self.fullName = fullName
        self.isPrivate = isPrivate
        self.url = url
    }
    
    // Convenience initializer from GitHub Repository model
    public init(from repository: Repository) {
        self.owner = repository.owner.login
        self.name = repository.name
        self.fullName = repository.fullName
        self.isPrivate = repository.private
        self.url = repository.htmlUrl
    }
    
    public var displayName: String {
        return fullName
    }
}

// MARK: - Repository Manager

public class RepositoryManager {
    
    private let userDefaults = UserDefaults.standard
    private let repositoriesKey = "HarbingerMonitoredRepositories"
    private let gitHubClient = GitHubClient()
    
    public init() {}
    
    // MARK: - Repository Management
    
    public func getMonitoredRepositories() -> [MonitoredRepository] {
        guard let data = userDefaults.data(forKey: repositoriesKey) else {
            return []
        }
        
        do {
            let repositories = try JSONDecoder().decode([MonitoredRepository].self, from: data)
            return repositories
        } catch {
            print("❌ RepositoryManager: Failed to decode repositories: \(error)")
            return []
        }
    }
    
    public func addRepository(_ repository: MonitoredRepository) -> Bool {
        var repositories = getMonitoredRepositories()
        
        // Check if repository is already being monitored
        if repositories.contains(repository) {
            print("ℹ️ RepositoryManager: Repository \(repository.displayName) is already being monitored")
            return false
        }
        
        repositories.append(repository)
        return saveRepositories(repositories)
    }
    
    public func removeRepository(_ repository: MonitoredRepository) -> Bool {
        var repositories = getMonitoredRepositories()
        repositories.removeAll { $0 == repository }
        return saveRepositories(repositories)
    }
    
    public func removeRepository(fullName: String) -> Bool {
        var repositories = getMonitoredRepositories()
        repositories.removeAll { $0.fullName == fullName }
        return saveRepositories(repositories)
    }
    
    public func isRepositoryMonitored(_ repository: MonitoredRepository) -> Bool {
        return getMonitoredRepositories().contains(repository)
    }
    
    public func isRepositoryMonitored(fullName: String) -> Bool {
        return getMonitoredRepositories().contains { $0.fullName == fullName }
    }
    
    private func saveRepositories(_ repositories: [MonitoredRepository]) -> Bool {
        do {
            let data = try JSONEncoder().encode(repositories)
            userDefaults.set(data, forKey: repositoriesKey)
            print("✅ RepositoryManager: Saved \(repositories.count) repositories")
            return true
        } catch {
            print("❌ RepositoryManager: Failed to save repositories: \(error)")
            return false
        }
    }
    
    // MARK: - Repository Discovery
    
    public func fetchAvailableRepositories(completion: @escaping (Result<[Repository], GitHubClient.GitHubError>) -> Void) {
        guard GitHubOAuthConfig.isConfigured else {
            completion(.failure(.authenticationError))
            return
        }
        
        var allRepositories: [Repository] = []
        var completedRequests = 0
        let totalRequests = 2 // User repos + organizations
        var hasError: GitHubClient.GitHubError?
        
        let completeIfDone = {
            completedRequests += 1
            if completedRequests == totalRequests {
                if let error = hasError {
                    completion(.failure(error))
                } else {
                    print("📊 RepositoryManager: Total repositories before deduplication: \(allRepositories.count)")
                    
                    // Remove duplicates and sort
                    let uniqueRepos = Array(Set(allRepositories.map { $0.id })).compactMap { id in
                        allRepositories.first { $0.id == id }
                    }.sorted { $0.fullName < $1.fullName }
                    
                    print("📊 RepositoryManager: Total unique repositories after deduplication: \(uniqueRepos.count)")
                    print("📊 RepositoryManager: Sample repositories: \(uniqueRepos.prefix(5).map { $0.fullName })")
                    
                    completion(.success(uniqueRepos))
                }
            }
        }
        
        // Fetch user repositories
        gitHubClient.getRepositories { result in
            switch result {
            case .success(let repos):
                print("📊 RepositoryManager: Found \(repos.count) user repositories")
                allRepositories.append(contentsOf: repos)
            case .failure(let error):
                print("❌ RepositoryManager: Failed to fetch user repositories: \(error)")
                hasError = error
            }
            completeIfDone()
        }
        
        // Fetch organizations, then their repositories
        gitHubClient.getUserOrganizations { [weak self] result in
            switch result {
            case .success(let organizations):
                print("📊 RepositoryManager: Found \(organizations.count) organizations: \(organizations.map { $0.login })")
                if organizations.isEmpty {
                    completeIfDone()
                    return
                }
                
                var orgReposCompleted = 0
                let totalOrgs = organizations.count
                
                for org in organizations {
                    print("🏢 RepositoryManager: Fetching repositories for organization: \(org.login)")
                    self?.gitHubClient.getOrganizationRepositories(org: org.login) { orgRepoResult in
                        switch orgRepoResult {
                        case .success(let orgRepos):
                            print("📊 RepositoryManager: Found \(orgRepos.count) repositories in organization \(org.login)")
                            allRepositories.append(contentsOf: orgRepos)
                        case .failure(let error):
                            // Don't fail entire operation if one org fails
                            print("❌ RepositoryManager: Failed to fetch repos for org \(org.login): \(error)")
                        }
                        
                        orgReposCompleted += 1
                        if orgReposCompleted == totalOrgs {
                            completeIfDone()
                        }
                    }
                }
            case .failure(let error):
                hasError = error
                completeIfDone()
            }
        }
    }
}