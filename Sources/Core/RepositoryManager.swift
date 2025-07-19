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
        
        let gitHubClient = GitHubClient()
        gitHubClient.getRepositories(completion: completion)
    }
}