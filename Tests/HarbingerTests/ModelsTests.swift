import XCTest
@testable import HarbingerCore

final class ModelsTests: XCTestCase {
    
    // MARK: - WorkflowRun Model Tests
    
    func testWorkflowRunModelDecoding() throws {
        let jsonData = """
        {
            "total_count": 1,
            "workflow_runs": [
                {
                    "id": 123456,
                    "name": "Test Workflow",
                    "head_branch": "main",
                    "head_sha": "abc123def456",
                    "run_number": 42,
                    "event": "push",
                    "status": "completed",
                    "conclusion": "success",
                    "workflow_id": 789,
                    "url": "https://api.github.com/repos/test/repo/actions/runs/123456",
                    "html_url": "https://github.com/test/repo/actions/runs/123456",
                    "created_at": "2023-01-01T12:00:00Z",
                    "updated_at": "2023-01-01T12:05:00Z",
                    "run_started_at": "2023-01-01T12:00:30Z",
                    "jobs_url": "https://api.github.com/repos/test/repo/actions/runs/123456/jobs",
                    "logs_url": "https://api.github.com/repos/test/repo/actions/runs/123456/logs",
                    "check_suite_url": "https://api.github.com/repos/test/repo/check-suites/123",
                    "artifacts_url": "https://api.github.com/repos/test/repo/actions/runs/123456/artifacts",
                    "cancel_url": "https://api.github.com/repos/test/repo/actions/runs/123456/cancel",
                    "rerun_url": "https://api.github.com/repos/test/repo/actions/runs/123456/rerun",
                    "workflow_url": "https://api.github.com/repos/test/repo/actions/workflows/789",
                    "head_commit": {
                        "id": "abc123def456",
                        "tree_id": "tree123",
                        "message": "Test commit",
                        "timestamp": "2023-01-01T11:59:00Z",
                        "author": {
                            "name": "Test Author",
                            "email": "test@example.com"
                        },
                        "committer": {
                            "name": "Test Author",
                            "email": "test@example.com"
                        }
                    },
                    "repository": {
                        "id": 456,
                        "name": "repo",
                        "full_name": "test/repo",
                        "owner": {
                            "login": "test",
                            "id": 789,
                            "avatar_url": "https://github.com/avatar.png",
                            "type": "User"
                        },
                        "private": false,
                        "html_url": "https://github.com/test/repo",
                        "description": "Test repository",
                        "fork": false,
                        "archived": false,
                        "disabled": false
                    },
                    "head_repository": {
                        "id": 456,
                        "name": "repo",
                        "full_name": "test/repo",
                        "owner": {
                            "login": "test",
                            "id": 789,
                            "avatar_url": "https://github.com/avatar.png",
                            "type": "User"
                        },
                        "private": false,
                        "html_url": "https://github.com/test/repo",
                        "description": "Test repository",
                        "fork": false,
                        "archived": false,
                        "disabled": false
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let workflowRuns = try decoder.decode(WorkflowRunsResponse.self, from: jsonData)
        
        XCTAssertEqual(workflowRuns.totalCount, 1)
        XCTAssertEqual(workflowRuns.workflowRuns.count, 1)
        
        let run = workflowRuns.workflowRuns[0]
        XCTAssertEqual(run.name, "Test Workflow")
        XCTAssertEqual(run.status, "completed")
        XCTAssertEqual(run.conclusion, "success")
        XCTAssertTrue(run.isSuccessful)
        XCTAssertTrue(run.isCompleted)
        XCTAssertFalse(run.isRunning)
        XCTAssertEqual(run.displayStatus, "Success")
        XCTAssertEqual(run.statusColor.description, "Success")
        
        print("✅ Successfully decoded workflow run model")
    }
    
    func testWorkflowRunStatusMapping() {
        // Test different workflow status mappings
        let testCases: [(status: String, conclusion: String?, expectedColor: WorkflowRunStatus)] = [
            ("completed", "success", .success),
            ("completed", "failure", .failure),
            ("completed", "cancelled", .unknown),
            ("in_progress", nil, .running),
            ("queued", nil, .running),
            ("completed", "skipped", .unknown)
        ]
        
        for testCase in testCases {
            // Create a minimal workflow run for testing
            let jsonData = """
            {
                "id": 123,
                "name": "Test",
                "head_branch": "main",
                "head_sha": "abc123",
                "run_number": 1,
                "event": "push",
                "status": "\(testCase.status)",
                "conclusion": \(testCase.conclusion.map { "\"\($0)\"" } ?? "null"),
                "workflow_id": 1,
                "url": "https://api.github.com/test",
                "html_url": "https://github.com/test",
                "created_at": "2023-01-01T12:00:00Z",
                "updated_at": "2023-01-01T12:00:00Z",
                "jobs_url": "https://api.github.com/test/jobs",
                "logs_url": "https://api.github.com/test/logs",
                "check_suite_url": "https://api.github.com/test/check",
                "artifacts_url": "https://api.github.com/test/artifacts",
                "cancel_url": "https://api.github.com/test/cancel",
                "rerun_url": "https://api.github.com/test/rerun",
                "workflow_url": "https://api.github.com/test/workflow",
                "head_commit": {
                    "id": "abc123",
                    "tree_id": "tree123",
                    "message": "Test",
                    "timestamp": "2023-01-01T12:00:00Z",
                    "author": {"name": "Test", "email": "test@test.com"},
                    "committer": {"name": "Test", "email": "test@test.com"}
                },
                "repository": {
                    "id": 1,
                    "name": "test",
                    "full_name": "test/test",
                    "owner": {"login": "test", "id": 1, "avatar_url": "test", "type": "User"},
                    "private": false,
                    "html_url": "https://github.com/test",
                    "description": "Test",
                    "fork": false,
                    "archived": false,
                    "disabled": false
                },
                "head_repository": {
                    "id": 1,
                    "name": "test",
                    "full_name": "test/test",
                    "owner": {"login": "test", "id": 1, "avatar_url": "test", "type": "User"},
                    "private": false,
                    "html_url": "https://github.com/test",
                    "description": "Test",
                    "fork": false,
                    "archived": false,
                    "disabled": false
                }
            }
            """.data(using: .utf8)!
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let run = try decoder.decode(WorkflowRun.self, from: jsonData)
                XCTAssertEqual(run.statusColor, testCase.expectedColor, 
                             "Status '\(testCase.status)' with conclusion '\(testCase.conclusion ?? "nil")' should map to \(testCase.expectedColor)")
            } catch {
                XCTFail("Failed to decode test case: \(error)")
            }
        }
    }
    
    // MARK: - Repository Model Tests
    
    func testRepositoryModelDecoding() throws {
        let jsonData = """
        {
            "id": 123,
            "name": "test-repo",
            "full_name": "owner/test-repo",
            "owner": {
                "login": "owner",
                "id": 456,
                "avatar_url": "https://github.com/avatar.png",
                "type": "User"
            },
            "private": true,
            "html_url": "https://github.com/owner/test-repo",
            "description": "A test repository",
            "fork": false,
            "archived": false,
            "disabled": false,
            "has_actions": true,
            "default_branch": "main",
            "language": "Swift",
            "updated_at": "2023-01-01T12:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let repository = try decoder.decode(Repository.self, from: jsonData)
        
        XCTAssertEqual(repository.name, "test-repo")
        XCTAssertEqual(repository.fullName, "owner/test-repo")
        XCTAssertEqual(repository.displayName, "owner/test-repo")
        XCTAssertEqual(repository.ownerName, "owner")
        XCTAssertTrue(repository.`private`)
        // XCTAssertTrue(repository.isActive) // isActive is not a property of Repository
        XCTAssertEqual(repository.language, "Swift")
        
        print("✅ Successfully decoded repository model")
    }
    
    // MARK: - Workflow Model Tests
    
    func testWorkflowModelDecoding() throws {
        let jsonData = """
        {
            "total_count": 1,
            "workflows": [
                {
                    "id": 789,
                    "name": "CI",
                    "path": ".github/workflows/ci.yml",
                    "state": "active",
                    "created_at": "2023-01-01T12:00:00Z",
                    "updated_at": "2023-01-01T12:00:00Z",
                    "url": "https://api.github.com/repos/test/repo/actions/workflows/789",
                    "html_url": "https://github.com/test/repo/actions/workflows/ci.yml",
                    "badge_url": "https://github.com/test/repo/workflows/CI/badge.svg"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let workflows = try decoder.decode(WorkflowsResponse.self, from: jsonData)
        
        XCTAssertEqual(workflows.totalCount, 1)
        XCTAssertEqual(workflows.workflows.count, 1)
        
        let workflow = workflows.workflows[0]
        XCTAssertEqual(workflow.name, "CI")
        XCTAssertEqual(workflow.state, "active")
        XCTAssertTrue(workflow.isActive)
        XCTAssertEqual(workflow.path, ".github/workflows/ci.yml")
        
        print("✅ Successfully decoded workflow model")
    }
    
    // MARK: - WorkflowRunStatus Enum Tests
    
    func testWorkflowRunStatusColors() {
        XCTAssertEqual(WorkflowRunStatus.success.color, "🟢")
        XCTAssertEqual(WorkflowRunStatus.failure.color, "🔴")
        XCTAssertEqual(WorkflowRunStatus.running.color, "🟡")
        XCTAssertEqual(WorkflowRunStatus.unknown.color, "⚪")
        
        XCTAssertEqual(WorkflowRunStatus.success.description, "Success")
        XCTAssertEqual(WorkflowRunStatus.failure.description, "Failed")
        XCTAssertEqual(WorkflowRunStatus.running.description, "Running")
        XCTAssertEqual(WorkflowRunStatus.unknown.description, "Unknown")
    }
}