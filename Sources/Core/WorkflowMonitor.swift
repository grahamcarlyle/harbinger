import Foundation
import Cocoa

// MARK: - Workflow Status Models

public struct RepositoryWorkflowStatus {
    public let repository: MonitoredRepository
    public let workflows: [WorkflowRunSummary]
    public let lastUpdated: Date
    public let error: String?
    
    public init(repository: MonitoredRepository, workflows: [WorkflowRunSummary], lastUpdated: Date = Date(), error: String? = nil) {
        self.repository = repository
        self.workflows = workflows
        self.lastUpdated = lastUpdated
        self.error = error
    }
    
    public var overallStatus: WorkflowRunStatus {
        guard error == nil else { return .unknown }
        
        if workflows.isEmpty {
            return .unknown
        }
        
        // Base status on the most recent workflow run (first in the array)
        // This matches GitHub's repository status badge behavior
        let mostRecentWorkflow = workflows.first!
        
        return mostRecentWorkflow.status
    }
    
    public var statusDescription: String {
        guard !workflows.isEmpty else {
            if let error = error {
                return "⚠️ Error: \(error)"
            } else {
                return "⚪ No workflow data"
            }
        }
        
        let mostRecentWorkflow = workflows.first!
        
        switch mostRecentWorkflow.status {
        case .success:
            return "✅ Latest workflow passed"
        case .failure:
            return "❌ Latest workflow failed"
        case .running:
            return "🟡 Workflow running"
        case .unknown:
            return "⚪ Status unknown"
        }
    }
}

public struct WorkflowRunSummary {
    public let name: String
    public let status: WorkflowRunStatus
    public let url: String
    public let commitSha: String
    public let updatedAt: Date
    public let commitMessage: String?
    public let commitAuthor: String?
    public let runAuthor: String?
    public let createdAt: Date?
    
    public init(name: String, status: WorkflowRunStatus, url: String, commitSha: String, updatedAt: Date, commitMessage: String? = nil, commitAuthor: String? = nil, runAuthor: String? = nil, createdAt: Date? = nil) {
        self.name = name
        self.status = status
        self.url = url
        self.commitSha = commitSha
        self.updatedAt = updatedAt
        self.commitMessage = commitMessage
        self.commitAuthor = commitAuthor
        self.runAuthor = runAuthor
        self.createdAt = createdAt
    }
    
    public init(from workflowRun: WorkflowRun) {
        self.name = workflowRun.name ?? "Unknown Workflow"
        self.status = workflowRun.statusColor
        self.url = workflowRun.htmlUrl
        self.commitSha = workflowRun.headSha
        
        // Extract commit message and author information
        self.commitMessage = workflowRun.headCommit.message
        self.commitAuthor = workflowRun.headCommit.author.name
        self.runAuthor = workflowRun.actor?.login
        
        // Parse ISO date strings
        let dateFormatter = ISO8601DateFormatter()
        self.updatedAt = dateFormatter.date(from: workflowRun.updatedAt) ?? Date()
        self.createdAt = dateFormatter.date(from: workflowRun.createdAt)
    }
    
    public var statusEmoji: String {
        switch status {
        case .success: return "✅"
        case .failure: return "❌"
        case .running: return "🟡"
        case .unknown: return "⚪"
        }
    }
    
    // SF Symbols version for Apple HIG compliance with semantic colors
    public func statusIcon() -> NSImage? {
        let symbolName: String
        switch status {
        case .success:
            symbolName = "checkmark.circle.fill"
        case .failure:
            symbolName = "xmark.circle.fill"
        case .running:
            symbolName = "hourglass.circle.fill"
        case .unknown:
            symbolName = "questionmark.circle.fill"
        }
        
        let description = "\(status)"
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) else {
            return nil
        }
        
        // Apply semantic colors for enhanced visibility
        let color: NSColor
        switch status {
        case .success:
            color = .systemGreen
        case .failure:
            color = .systemRed  // Critical red for failures
        case .running:
            color = .systemYellow
        case .unknown:
            color = .systemGray
        }
        
        // Create tinted version
        let tintedImage = image.copy() as! NSImage
        tintedImage.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: NSCompositingOperation.sourceAtop)
        tintedImage.unlockFocus()
        
        return tintedImage
    }
    
    public var shortCommitSha: String {
        return String(commitSha.prefix(7))
    }
    
    public var truncatedCommitMessage: String {
        guard let message = commitMessage else { return "No commit message" }
        // Get first line of commit message and truncate if needed
        let firstLine = message.components(separatedBy: .newlines).first ?? message
        let maxLength = 50
        if firstLine.count > maxLength {
            return String(firstLine.prefix(maxLength)) + "..."
        }
        return firstLine
    }
    
    public var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        if let created = createdAt {
            return formatter.localizedString(for: created, relativeTo: Date())
        } else {
            return formatter.localizedString(for: updatedAt, relativeTo: Date())
        }
    }
    
    public var displayAuthor: String {
        return runAuthor ?? commitAuthor ?? "Unknown"
    }
}

// MARK: - Workflow Monitor

public class WorkflowMonitor {
    
    private let repositoryManager = RepositoryManager()
    private let gitHubClient = GitHubClient()
    
    private var statusCache: [String: RepositoryWorkflowStatus] = [:]
    private var isMonitoring = false
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    public weak var delegate: WorkflowMonitorDelegate?
    
    public init() {
        StatusBarDebugger.shared.log(.lifecycle, "WorkflowMonitor initialized")
    }
    
    // MARK: - Public Interface
    
    public func startMonitoring() {
        guard !isMonitoring else { 
            StatusBarDebugger.shared.log(.warning, "Attempted to start monitoring but already running")
            return 
        }
        
        isMonitoring = true
        StatusBarDebugger.shared.log(.lifecycle, "Starting workflow monitoring")
        
        refreshAllRepositories()
        startPeriodicRefresh()
    }
    
    public func stopMonitoring() {
        guard isMonitoring else {
            StatusBarDebugger.shared.log(.warning, "Attempted to stop monitoring but not running")
            return
        }
        
        isMonitoring = false
        stopPeriodicRefresh()
        StatusBarDebugger.shared.log(.lifecycle, "Stopped workflow monitoring")
    }
    
    private func startPeriodicRefresh() {
        stopPeriodicRefresh() // Ensure no duplicate timers
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] timer in
            StatusBarDebugger.shared.log(.timer, "Periodic refresh triggered")
            self?.refreshAllRepositories()
        }
        
        StatusBarDebugger.shared.log(.timer, "Periodic refresh started", context: ["interval": refreshInterval])
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        StatusBarDebugger.shared.log(.timer, "Periodic refresh stopped")
    }
    
    public func refreshAllRepositories() {
        let repositories = repositoryManager.getMonitoredRepositories()
        
        guard !repositories.isEmpty else {
            StatusBarDebugger.shared.log(.lifecycle, "WorkflowMonitor: No repositories to monitor")
            delegate?.workflowMonitor(self, didUpdateOverallStatus: .unknown, statusText: "No repositories monitored")
            return
        }
        
        StatusBarDebugger.shared.log(.network, "Refreshing repositories", context: ["count": repositories.count])
        
        let group = DispatchGroup()
        var newStatusCache: [String: RepositoryWorkflowStatus] = [:]
        
        for repository in repositories {
            group.enter()
            fetchWorkflowStatus(for: repository) { [weak self] status in
                newStatusCache[repository.fullName] = status
                self?.delegate?.workflowMonitor(self!, didUpdateRepository: status)
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            self.statusCache = newStatusCache
            let overallStatus = self.calculateOverallStatus()
            let statusText = self.generateOverallStatusText()
            
            StatusBarDebugger.shared.log(.network, "Completed refresh", context: ["overallStatus": "\(overallStatus)"])
            self.delegate?.workflowMonitor(self, didUpdateOverallStatus: overallStatus, statusText: statusText)
        }
    }
    
    public func getRepositoryStatuses() -> [RepositoryWorkflowStatus] {
        return Array(statusCache.values).sorted { $0.repository.fullName < $1.repository.fullName }
    }
    
    public func getOverallStatus() -> (status: WorkflowRunStatus, text: String) {
        return (calculateOverallStatus(), generateOverallStatusText())
    }
    
    // MARK: - Private Methods
    
    private func fetchWorkflowStatus(for repository: MonitoredRepository, completion: @escaping (RepositoryWorkflowStatus) -> Void) {
        StatusBarDebugger.shared.log(.network, "Fetching workflows for repository", context: ["repository": repository.fullName])
        
        gitHubClient.getWorkflowRuns(owner: repository.owner, repo: repository.name) { result in
            switch result {
            case .success(let workflowRuns):
                StatusBarDebugger.shared.log(.network, "Fetched workflow runs for repository", context: ["count": workflowRuns.workflowRuns.count, "repository": repository.fullName])
                
                // Filter workflow runs based on repository's tracking configuration
                let filteredRuns = workflowRuns.workflowRuns.filter { workflowRun in
                    // If no specific workflows are configured, track all workflows (default behavior)
                    guard repository.hasSpecificWorkflowsConfigured else {
                        return true
                    }
                    
                    // Only include workflows that are explicitly tracked
                    let workflowName = workflowRun.name ?? "Unknown Workflow"
                    return repository.isWorkflowTracked(workflowName)
                }
                
                StatusBarDebugger.shared.log(.network, "Filtered to tracked workflow runs for repository", context: ["filteredCount": filteredRuns.count, "repository": repository.fullName])
                if repository.hasSpecificWorkflowsConfigured {
                    StatusBarDebugger.shared.log(.state, "Tracking specific workflows", context: ["workflows": repository.trackedWorkflowNames, "repository": repository.fullName])
                }
                
                // Get latest workflow runs (limit to recent ones)
                let recentRuns = Array(filteredRuns.prefix(10))
                let workflowSummaries = recentRuns.map { WorkflowRunSummary(from: $0) }
                
                let status = RepositoryWorkflowStatus(
                    repository: repository,
                    workflows: workflowSummaries,
                    lastUpdated: Date()
                )
                
                completion(status)
                
            case .failure(let error):
                StatusBarDebugger.shared.log(.error, "Failed to fetch workflows for repository", context: ["repository": repository.fullName, "error": error.localizedDescription])
                
                let status = RepositoryWorkflowStatus(
                    repository: repository,
                    workflows: [],
                    lastUpdated: Date(),
                    error: error.localizedDescription
                )
                
                completion(status)
            }
        }
    }
    
    private func calculateOverallStatus() -> WorkflowRunStatus {
        let allStatuses = statusCache.values
        
        guard !allStatuses.isEmpty else { return .unknown }
        
        // If any repository has an error, but others are working, show the working status
        let workingStatuses = allStatuses.filter { $0.error == nil }
        
        if workingStatuses.isEmpty {
            return .unknown // All repositories have errors
        }
        
        // Check for failures first
        if workingStatuses.contains(where: { $0.overallStatus == .failure }) {
            return .failure
        }
        
        // Check for running workflows
        if workingStatuses.contains(where: { $0.overallStatus == .running }) {
            return .running
        }
        
        // Check if all working repositories are successful
        if workingStatuses.allSatisfy({ $0.overallStatus == .success }) {
            return .success
        }
        
        return .unknown
    }
    
    private func generateOverallStatusText() -> String {
        let repositories = Array(statusCache.values)
        let totalRepos = repositories.count
        
        guard totalRepos > 0 else {
            return "No repositories monitored"
        }
        
        let overallStatus = calculateOverallStatus()
        
        switch overallStatus {
        case .success:
            return "All \(totalRepos) repositories passing"
        case .failure:
            let failingRepos = repositories.filter { $0.overallStatus == .failure }.count
            return "\(failingRepos) of \(totalRepos) repositories failing"
        case .running:
            let runningRepos = repositories.filter { $0.overallStatus == .running }.count
            return "\(runningRepos) of \(totalRepos) repositories running workflows"
        case .unknown:
            let errorRepos = repositories.filter { $0.error != nil }.count
            if errorRepos == totalRepos {
                return "All repositories have errors"
            } else if errorRepos > 0 {
                return "\(errorRepos) of \(totalRepos) repositories have errors"
            } else {
                return "No workflow data available"
            }
        }
    }
}

// MARK: - Delegate Protocol

public protocol WorkflowMonitorDelegate: AnyObject {
    func workflowMonitor(_ monitor: WorkflowMonitor, didUpdateOverallStatus status: WorkflowRunStatus, statusText: String)
    func workflowMonitor(_ monitor: WorkflowMonitor, didUpdateRepository repositoryStatus: RepositoryWorkflowStatus)
}