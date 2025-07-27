import Foundation

// MARK: - Data Models

public struct MonitoredRepository: Codable, Equatable {
    public let owner: String
    public let name: String
    public let fullName: String
    public let isPrivate: Bool
    public let url: String
    public let description: String?
    public var trackedWorkflows: [String: Bool] // workflow name -> enabled
    public let addedAt: Date
    
    public init(owner: String, name: String, fullName: String, isPrivate: Bool, url: String, description: String? = nil, trackedWorkflows: [String: Bool] = [:]) {
        self.owner = owner
        self.name = name
        self.fullName = fullName
        self.isPrivate = isPrivate
        self.url = url
        self.description = description
        self.trackedWorkflows = trackedWorkflows
        self.addedAt = Date()
    }
    
    // Convenience initializer from GitHub Repository model
    public init(from repository: Repository) {
        self.owner = repository.owner.login
        self.name = repository.name
        self.fullName = repository.fullName
        self.isPrivate = repository.private
        self.url = repository.htmlUrl
        self.description = repository.description
        self.trackedWorkflows = [:] // Start with no specific workflows tracked
        self.addedAt = Date()
    }
    
    public var displayName: String {
        return fullName
    }
    
    // Workflow tracking management
    public func isWorkflowTracked(_ workflowName: String) -> Bool {
        // If no specific workflows are configured, track all workflows (default behavior)
        if trackedWorkflows.isEmpty {
            return true
        }
        return trackedWorkflows[workflowName] ?? false
    }
    
    public var hasSpecificWorkflowsConfigured: Bool {
        return !trackedWorkflows.isEmpty
    }
    
    public var trackedWorkflowNames: [String] {
        return trackedWorkflows.compactMap { name, enabled in
            enabled ? name : nil
        }.sorted()
    }
    
    public var allConfiguredWorkflowNames: [String] {
        return Array(trackedWorkflows.keys).sorted()
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
            StatusBarDebugger.shared.log(.error, "Failed to decode repositories", context: ["error": error.localizedDescription])
            return []
        }
    }
    
    public func addRepository(_ repository: MonitoredRepository) -> Bool {
        var repositories = getMonitoredRepositories()
        
        // Check if repository is already being monitored
        if repositories.contains(repository) {
            StatusBarDebugger.shared.log(.warning, "Repository is already being monitored", context: ["repository": repository.displayName])
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
    
    // MARK: - Workflow Tracking Management
    
    public func updateWorkflowTracking(for repositoryFullName: String, workflowName: String, enabled: Bool) -> Bool {
        var repositories = getMonitoredRepositories()
        
        guard let index = repositories.firstIndex(where: { $0.fullName == repositoryFullName }) else {
            StatusBarDebugger.shared.log(.error, "Repository not found for workflow update", context: ["repository": repositoryFullName])
            return false
        }
        
        // Create a new instance with updated workflow tracking since struct is immutable
        var updatedRepo = repositories[index]
        updatedRepo.trackedWorkflows[workflowName] = enabled
        repositories[index] = updatedRepo
        return saveRepositories(repositories)
    }
    
    public func setTrackedWorkflows(for repositoryFullName: String, workflows: [String: Bool]) -> Bool {
        var repositories = getMonitoredRepositories()
        
        guard let index = repositories.firstIndex(where: { $0.fullName == repositoryFullName }) else {
            StatusBarDebugger.shared.log(.error, "Repository not found for workflow update", context: ["repository": repositoryFullName])
            return false
        }
        
        // Create a new instance with updated workflow tracking since struct is immutable
        var updatedRepo = repositories[index]
        updatedRepo.trackedWorkflows = workflows
        repositories[index] = updatedRepo
        return saveRepositories(repositories)
    }
    
    public func getMonitoredRepository(fullName: String) -> MonitoredRepository? {
        return getMonitoredRepositories().first { $0.fullName == fullName }
    }
    
    private func saveRepositories(_ repositories: [MonitoredRepository]) -> Bool {
        do {
            let data = try JSONEncoder().encode(repositories)
            userDefaults.set(data, forKey: repositoriesKey)
            StatusBarDebugger.shared.log(.state, "Saved repositories", context: ["count": repositories.count])
            return true
        } catch {
            StatusBarDebugger.shared.log(.error, "Failed to save repositories", context: ["error": error.localizedDescription])
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
                    StatusBarDebugger.shared.log(.network, "Total repositories before deduplication", context: ["count": allRepositories.count])
                    
                    // Remove duplicates and sort (using fullName since id field is commented out)
                    let uniqueRepos = Array(Set(allRepositories.map { $0.fullName })).compactMap { fullName in
                        allRepositories.first { $0.fullName == fullName }
                    }.sorted { $0.fullName < $1.fullName }
                    
                    StatusBarDebugger.shared.log(.network, "Total unique repositories after deduplication", context: ["count": uniqueRepos.count])
                    StatusBarDebugger.shared.log(.network, "Sample repositories", context: ["sample": uniqueRepos.prefix(5).map { $0.fullName }])
                    
                    completion(.success(uniqueRepos))
                }
            }
        }
        
        // Fetch user repositories
        gitHubClient.getRepositories { result in
            switch result {
            case .success(let repos):
                StatusBarDebugger.shared.log(.network, "Found user repositories", context: ["count": repos.count])
                allRepositories.append(contentsOf: repos)
            case .failure(let error):
                StatusBarDebugger.shared.log(.error, "Failed to fetch user repositories", context: ["error": error.localizedDescription])
                hasError = error
            }
            completeIfDone()
        }
        
        // Fetch organizations, then their repositories
        gitHubClient.getUserOrganizations { [weak self] result in
            switch result {
            case .success(let organizations):
                StatusBarDebugger.shared.log(.network, "Found organizations", context: ["count": organizations.count, "organizations": organizations.map { $0.login }])
                if organizations.isEmpty {
                    completeIfDone()
                    return
                }
                
                var orgReposCompleted = 0
                let totalOrgs = organizations.count
                
                for org in organizations {
                    StatusBarDebugger.shared.log(.network, "Fetching repositories for organization", context: ["organization": org.login])
                    self?.gitHubClient.getOrganizationRepositories(org: org.login) { orgRepoResult in
                        switch orgRepoResult {
                        case .success(let orgRepos):
                            StatusBarDebugger.shared.log(.network, "Found repositories in organization", context: ["count": orgRepos.count, "organization": org.login])
                            allRepositories.append(contentsOf: orgRepos)
                        case .failure(let error):
                            // Don't fail entire operation if one org fails
                            StatusBarDebugger.shared.log(.error, "Failed to fetch repos for organization", context: ["organization": org.login, "error": error.localizedDescription])
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