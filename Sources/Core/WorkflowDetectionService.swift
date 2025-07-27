import Foundation

// Service for detecting if repositories have GitHub Actions workflows
public class WorkflowDetectionService {
    
    public static let shared = WorkflowDetectionService()
    
    private let gitHubClient = GitHubClient()
    
    // Persistent cache management
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "WorkflowDetectionCache"
    
    // In-memory cache for quick access (loaded from persistent cache)
    private var workflowCache: [String: Bool] = [:]
    
    // Track ongoing requests to avoid duplicate API calls
    private var ongoingRequests: Set<String> = []
    
    // Queue for batching workflow detection requests
    private var pendingRequests: [(repository: Repository, completion: (Bool) -> Void)] = []
    
    // Timer for batching requests to avoid overwhelming the API
    private var batchTimer: Timer?
    
    private init() {
        loadCacheFromPersistentStorage()
    }
    
    // Check if a repository has workflows (with batching and caching)
    public func hasWorkflows(repository: Repository, completion: @escaping (Bool) -> Void) {
        let cacheKey = repository.fullName
        
        // Return cached result if available
        if let cachedResult = workflowCache[cacheKey] {
            completion(cachedResult)
            return
        }
        
        // Skip obviously non-viable repositories
        if !repository.isBasicallyViable {
            workflowCache[cacheKey] = false
            saveCacheToPersistentStorage()
            completion(false)
            return
        }
        
        // Add to pending requests for batched processing
        pendingRequests.append((repository: repository, completion: completion))
        
        // Start or reset the batch timer
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.processPendingRequests()
        }
    }
    
    // Process batched requests with rate limiting
    private func processPendingRequests() {
        guard !pendingRequests.isEmpty else { return }
        
        // Take only the first few requests to avoid API rate limiting
        let batchSize = min(5, pendingRequests.count)
        let batch = Array(pendingRequests.prefix(batchSize))
        pendingRequests.removeFirst(batchSize)
        
        // Process the batch
        for request in batch {
            checkSingleRepository(request.repository, completion: request.completion)
        }
        
        // Schedule next batch if there are more pending requests
        if !pendingRequests.isEmpty {
            batchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.processPendingRequests()
            }
        }
    }
    
    // Check a single repository for workflows
    private func checkSingleRepository(_ repository: Repository, completion: @escaping (Bool) -> Void) {
        let cacheKey = repository.fullName
        
        // Skip if already checking this repository
        if ongoingRequests.contains(cacheKey) {
            completion(false) // Return false for ongoing requests to avoid blocking
            return
        }
        
        // Start workflow detection
        ongoingRequests.insert(cacheKey)
        
        gitHubClient.getWorkflows(owner: repository.ownerName, repo: repository.name) { [weak self] result in
            DispatchQueue.main.async {
                self?.ongoingRequests.remove(cacheKey)
                
                switch result {
                case .success(let workflowResponse):
                    let hasWorkflows = !workflowResponse.workflows.isEmpty
                    self?.workflowCache[cacheKey] = hasWorkflows
                    self?.saveCacheToPersistentStorage()
                    completion(hasWorkflows)
                    
                case .failure(let error):
                    // On error, assume repository has no workflows to be conservative
                    StatusBarDebugger.shared.log(.warning, "Failed to check workflows", context: ["cacheKey": cacheKey, "error": error.localizedDescription])
                    self?.workflowCache[cacheKey] = false  // Conservative approach on error
                    self?.saveCacheToPersistentStorage()
                    completion(false)
                }
            }
        }
    }
    
    // Get cached result only (non-async)
    public func getCachedWorkflowStatus(for repository: Repository) -> Bool? {
        return workflowCache[repository.fullName]
    }
    
    // Clear cache (for testing or refresh scenarios)
    public func clearCache() {
        workflowCache.removeAll()
        ongoingRequests.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    // Pre-populate cache with known results (for testing)
    public func setCachedResult(repository: String, hasWorkflows: Bool) {
        workflowCache[repository] = hasWorkflows
        saveCacheToPersistentStorage()
    }
    
    // MARK: - Persistent Cache Management
    
    private func loadCacheFromPersistentStorage() {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            StatusBarDebugger.shared.log(.network, "No persistent cache found")
            return
        }
        
        do {
            let cachedData = try JSONDecoder().decode(CachedWorkflowData.self, from: data)
            
            if cachedData.isExpired {
                StatusBarDebugger.shared.log(.network, "Persistent cache expired, clearing")
                userDefaults.removeObject(forKey: cacheKey)
                return
            }
            
            workflowCache = cachedData.workflowStatus
            StatusBarDebugger.shared.log(.network, "Loaded items from persistent cache", context: ["count": workflowCache.count])
        } catch {
            StatusBarDebugger.shared.log(.warning, "Failed to load persistent cache", context: ["error": error.localizedDescription])
            userDefaults.removeObject(forKey: cacheKey)
        }
    }
    
    private func saveCacheToPersistentStorage() {
        let cachedData = CachedWorkflowData(workflowStatus: workflowCache)
        
        do {
            let data = try JSONEncoder().encode(cachedData)
            userDefaults.set(data, forKey: cacheKey)
            StatusBarDebugger.shared.log(.network, "Saved items to persistent cache", context: ["count": workflowCache.count])
        } catch {
            StatusBarDebugger.shared.log(.warning, "Failed to save persistent cache", context: ["error": error.localizedDescription])
        }
    }
}