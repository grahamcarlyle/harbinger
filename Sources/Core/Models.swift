import Foundation

// MARK: - Repository Models

public struct Repository: Codable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepositoryOwner
    let `private`: Bool
    let htmlUrl: String
    let description: String?
    let fork: Bool
    let archived: Bool
    let disabled: Bool
    let hasActions: Bool?
    let defaultBranch: String
    let language: String?
    let updatedAt: String
    
    // Note: `private` is a Swift keyword, so we need to escape it with backticks
    
    // Computed properties for easier access
    var ownerName: String {
        return owner.login
    }
    
    public var displayName: String {
        return fullName
    }
    
    var isActive: Bool {
        return !archived && !disabled
    }
}

public struct RepositoryOwner: Codable {
    let login: String
    let id: Int
    let avatarUrl: String
    let type: String
    
    // Using automatic snake_case conversion
}

public struct Organization: Codable {
    let login: String
    let id: Int
    let url: String
    let reposUrl: String
    let description: String?
    
    // Using automatic snake_case conversion
}

// MARK: - Workflow Models

public struct WorkflowsResponse: Codable {
    let totalCount: Int
    let workflows: [Workflow]
    
    // Using automatic snake_case conversion
}

public struct Workflow: Codable {
    let id: Int
    let name: String
    let path: String
    let state: String
    let createdAt: String
    let updatedAt: String
    let url: String
    let htmlUrl: String
    let badgeUrl: String
    
    // Using automatic snake_case conversion
    
    var isActive: Bool {
        return state == "active"
    }
}

// MARK: - Workflow Run Models

public struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]
}

public struct WorkflowRun: Codable {
    let id: Int
    let name: String?
    let headBranch: String
    let headSha: String
    let runNumber: Int
    let event: String
    let status: String
    let conclusion: String?
    let workflowId: Int
    let url: String
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String
    let runStartedAt: String?
    let jobsUrl: String
    let logsUrl: String
    let checkSuiteUrl: String
    let artifactsUrl: String
    let cancelUrl: String
    let rerunUrl: String
    let workflowUrl: String
    let headCommit: HeadCommit
    let repository: WorkflowRepository
    let headRepository: WorkflowRepository
    
    // Optional fields that GitHub may include
    let pullRequests: [PullRequest]?
    let actor: GitHubUser?
    let triggeringActor: GitHubUser?
    let runAttempt: Int?
    // Temporarily ignore this field since it has inconsistent structure
    // let referencedWorkflows: [String]?
    let checkSuiteId: Int?
    let checkSuiteNodeId: String?
    let path: String?
    let displayTitle: String?
    let previousAttemptUrl: String?
    
    // Using automatic snake_case conversion, so no manual CodingKeys needed
    
    // Computed properties for easier status checking
    var isRunning: Bool {
        return status == "in_progress" || status == "queued"
    }
    
    var isCompleted: Bool {
        return status == "completed"
    }
    
    var isSuccessful: Bool {
        return conclusion == "success"
    }
    
    var isFailed: Bool {
        return conclusion == "failure"
    }
    
    var isCancelled: Bool {
        return conclusion == "cancelled"
    }
    
    var displayStatus: String {
        if isRunning {
            return "Running"
        } else if isSuccessful {
            return "Success"
        } else if isFailed {
            return "Failed"
        } else if isCancelled {
            return "Cancelled"
        } else {
            return conclusion?.capitalized ?? status.capitalized
        }
    }
    
    var statusColor: WorkflowRunStatus {
        if isRunning {
            return .running
        } else if isSuccessful {
            return .success
        } else if isFailed {
            return .failure
        } else {
            return .unknown
        }
    }
}

public struct HeadCommit: Codable {
    let id: String
    let treeId: String
    let message: String
    let timestamp: String
    let author: CommitAuthor
    let committer: CommitAuthor
}

public struct CommitAuthor: Codable {
    let name: String?
    let email: String?
}

public struct WorkflowRepository: Codable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepositoryOwner
    let `private`: Bool?
    let htmlUrl: String
    let description: String?
    let fork: Bool?
    let archived: Bool?
    let disabled: Bool?
    
    // Using automatic snake_case conversion
    // Note: Some fields may be optional in workflow run responses vs repository API responses
}

// MARK: - Status Enums

public enum WorkflowRunStatus {
    case success
    case failure
    case running
    case unknown
    
    var color: String {
        switch self {
        case .success:
            return "🟢"
        case .failure:
            return "🔴"
        case .running:
            return "🟡"
        case .unknown:
            return "⚪"
        }
    }
    
    var description: String {
        switch self {
        case .success:
            return "Success"
        case .failure:
            return "Failed"
        case .running:
            return "Running"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Legacy Workflow Status Models

struct WorkflowStatus {
    let workflowName: String
    let status: WorkflowRunStatus
    let lastRun: WorkflowRun?
    let url: String
    let lastUpdated: Date
    
    init(from workflowRun: WorkflowRun) {
        self.workflowName = workflowRun.name ?? "Workflow"
        self.status = workflowRun.statusColor
        self.lastRun = workflowRun
        self.url = workflowRun.htmlUrl
        self.lastUpdated = Date()
    }
}

// MARK: - API Error Models

struct GitHubAPIError: Codable {
    let message: String
    let errors: [GitHubAPIErrorDetail]?
    let documentationUrl: String?
    
    // Using automatic snake_case conversion
}

struct GitHubAPIErrorDetail: Codable {
    let resource: String?
    let field: String?
    let code: String
    let message: String?
}

// MARK: - Additional GitHub Models

public struct GitHubUser: Codable {
    let login: String
    let id: Int
    let nodeId: String?
    let avatarUrl: String?
    let gravatarId: String?
    let url: String?
    let htmlUrl: String?
    let type: String?
    let siteAdmin: Bool?
    
    // GitHub API returns many more fields for users, but we only need the essential ones
    // All other fields are ignored during decoding
    
    // Using automatic snake_case conversion
}

public struct PullRequest: Codable {
    let id: Int?
    let number: Int?
    let url: String?
    let htmlUrl: String?
    
    // Using automatic snake_case conversion
}