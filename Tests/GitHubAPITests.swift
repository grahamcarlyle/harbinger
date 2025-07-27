import XCTest
@testable import HarbingerCore

final class GitHubAPITests: XCTestCase {
    
    var gitHubClient: GitHubClient!
    
    override func setUp() {
        super.setUp()
        
        // Set up test-specific logging
        StatusBarDebugger.shared.setCurrentTest(self.name)
        
        gitHubClient = GitHubClient()
    }
    
    override func tearDown() {
        gitHubClient = nil
        
        // Clear test-specific logging
        StatusBarDebugger.shared.clearCurrentTest()
        
        super.tearDown()
    }
    
    // Test fetching workflow runs from a well-known public repository
    func testGetWorkflowRunsFromPublicRepo() throws {
        // Skip test if no OAuth token is available
        guard GitHubOAuthConfig.isConfigured else {
            throw XCTSkip("OAuth token not configured. Run app and authenticate first.")
        }
        
        let expectation = XCTestExpectation(description: "Fetch workflow runs")
        
        // Test against actions/runner-images repository which has many workflows
        gitHubClient.getWorkflowRuns(owner: "actions", repo: "runner-images") { result in
            switch result {
            case .success(let workflowRuns):
                XCTAssertGreaterThan(workflowRuns.workflowRuns.count, 0, "Should have at least one workflow run")
                
                if let firstRun = workflowRuns.workflowRuns.first {
                    XCTAssertFalse(firstRun.htmlUrl.isEmpty, "Workflow run should have HTML URL")
                    XCTAssertFalse(firstRun.headSha.isEmpty, "Workflow run should have commit SHA")
                    XCTAssertTrue(["completed", "in_progress", "queued"].contains(firstRun.status), 
                                "Workflow status should be valid")
                    
                    StatusBarDebugger.shared.log(.verification, "Found workflow run", context: [
                        "name": firstRun.name ?? "Unknown",
                        "status": firstRun.displayStatus,
                        "url": firstRun.htmlUrl,
                        "commit": firstRun.headSha
                    ])
                }
                
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch workflow runs: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // Test fetching workflows from a public repository
    func testGetWorkflowsFromPublicRepo() throws {
        guard GitHubOAuthConfig.isConfigured else {
            throw XCTSkip("OAuth token not configured. Run app and authenticate first.")
        }
        
        let expectation = XCTestExpectation(description: "Fetch workflows")
        
        // Test against nodejs/node repository which has workflows
        gitHubClient.getWorkflows(owner: "nodejs", repo: "node") { result in
            switch result {
            case .success(let workflows):
                XCTAssertGreaterThan(workflows.workflows.count, 0, "Should have at least one workflow")
                
                if let firstWorkflow = workflows.workflows.first {
                    XCTAssertFalse(firstWorkflow.name.isEmpty, "Workflow should have name")
                    XCTAssertFalse(firstWorkflow.htmlUrl.isEmpty, "Workflow should have HTML URL")
                    XCTAssertTrue(["active", "disabled"].contains(firstWorkflow.state), 
                                "Workflow state should be valid")
                    
                    StatusBarDebugger.shared.log(.verification, "Found workflow", context: [
                        "name": firstWorkflow.name,
                        "state": firstWorkflow.state,
                        "url": firstWorkflow.htmlUrl
                    ])
                }
                
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch workflows: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // Test fetching repositories (user's accessible repos)
    func testGetRepositories() throws {
        guard GitHubOAuthConfig.isConfigured else {
            throw XCTSkip("OAuth token not configured. Run app and authenticate first.")
        }
        
        let expectation = XCTestExpectation(description: "Fetch repositories")
        
        gitHubClient.getRepositories { result in
            switch result {
            case .success(let repositories):
                XCTAssertGreaterThan(repositories.count, 0, "Should have at least one repository")
                
                for repo in repositories.prefix(3) {
                    XCTAssertFalse(repo.name.isEmpty, "Repository should have name")
                    XCTAssertFalse(repo.fullName.isEmpty, "Repository should have full name")
                    XCTAssertFalse(repo.owner.login.isEmpty, "Repository should have owner")
                    
                    StatusBarDebugger.shared.log(.verification, "Found repository", context: [
                        "fullName": repo.fullName,
                        "private": "\(repo.`private`)"
                    ])
                }
                
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch repositories: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // Test authentication handling
    func testAuthenticationCheck() {
        let isAuthenticated = gitHubClient.isAuthenticated()
        
        if GitHubOAuthConfig.isConfigured {
            XCTAssertTrue(isAuthenticated, "Should be authenticated when token exists")
            StatusBarDebugger.shared.log(.verification, "Authentication check passed - token exists")
        } else {
            XCTAssertFalse(isAuthenticated, "Should not be authenticated when no token")
            StatusBarDebugger.shared.log(.state, "No token configured (expected for clean install)")
        }
    }
    
    // Test error handling with invalid repository
    func testErrorHandlingWithInvalidRepo() throws {
        guard GitHubOAuthConfig.isConfigured else {
            throw XCTSkip("OAuth token not configured. Run app and authenticate first.")
        }
        
        let expectation = XCTestExpectation(description: "Handle invalid repository")
        
        // Test with non-existent repository
        gitHubClient.getWorkflowRuns(owner: "nonexistent", repo: "invalid-repo-name-12345") { result in
            switch result {
            case .success(_):
                XCTFail("Should not succeed with invalid repository")
                
            case .failure(let error):
                StatusBarDebugger.shared.log(.verification, "Correctly handled error for invalid repository", context: ["error": error.localizedDescription])
                
                // Should be a 404 error
                if case GitHubClient.GitHubError.apiError(let message) = error {
                    XCTAssertTrue(message.contains("not found") || message.contains("404"), 
                                "Should be a 'not found' error")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // Performance test for API response time
    func testAPIResponseTime() throws {
        guard GitHubOAuthConfig.isConfigured else {
            throw XCTSkip("OAuth token not configured. Run app and authenticate first.")
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Measure API response time")
            
            gitHubClient.getWorkflowRuns(owner: "actions", repo: "runner-images") { result in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}