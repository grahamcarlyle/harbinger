import XCTest
@testable import HarbingerCore

final class OAuthConfigTests: XCTestCase {
    
    // MARK: - OAuth Scope Validation Tests
    
    func testOAuthScopeConfiguration() {
        // GitHub's official OAuth scopes as of 2025
        // Source: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps
        let validGitHubScopes = [
            // Repository access
            "repo",
            "public_repo",
            
            // User access
            "user",
            "user:email",
            
            // Organization access
            "admin:org",
            "write:org", 
            "read:org",
            
            // Repository hooks
            "admin:repo_hook",
            "write:repo_hook",
            "read:repo_hook",
            
            // Public keys
            "admin:public_key",
            "write:public_key",
            "read:public_key",
            
            // Organization hooks
            "admin:org_hook",
            
            // Other scopes
            "gist",
            "notifications",
            "delete_repo"
        ]
        
        print("🔍 Testing OAuth scope configuration...")
        print("   Configured scopes: \(GitHubOAuthConfig.scopes)")
        
        // Validate each configured scope against GitHub's official list
        for scope in GitHubOAuthConfig.scopes {
            XCTAssertTrue(
                validGitHubScopes.contains(scope), 
                """
                Invalid OAuth scope: '\(scope)'.
                
                Valid GitHub OAuth scopes are:
                \(validGitHubScopes.sorted().joined(separator: ", "))
                
                This test would have caught the invalid 'workflow' scope that caused authentication failure.
                """
            )
            print("   ✅ Valid scope: '\(scope)'")
        }
        
        print("✅ All OAuth scopes are valid!")
    }
    
    func testOAuthScopeRequirements() {
        // Ensure we have at least the minimum required scope for Harbinger
        XCTAssertTrue(
            GitHubOAuthConfig.scopes.contains("repo"),
            "Harbinger requires 'repo' scope for accessing repositories and GitHub Actions"
        )
        
        // Ensure we don't have unnecessary scopes that could be security risks
        let unnecessaryScopes = ["admin:org", "delete_repo", "admin:repo_hook"]
        for unnecessaryScope in unnecessaryScopes {
            XCTAssertFalse(
                GitHubOAuthConfig.scopes.contains(unnecessaryScope),
                "Scope '\(unnecessaryScope)' is not needed for Harbinger and increases security risk"
            )
        }
        
        print("✅ OAuth scope requirements validated")
    }
    
    // MARK: - OAuth Configuration Tests
    
    func testOAuthEndpointConfiguration() {
        // Validate OAuth endpoints are correct GitHub URLs
        XCTAssertEqual(
            GitHubOAuthConfig.baseURL, 
            "https://github.com",
            "OAuth base URL must be GitHub's official URL"
        )
        
        XCTAssertEqual(
            GitHubOAuthConfig.deviceCodeURL,
            "/login/device/code", 
            "Device code endpoint must match GitHub's OAuth device flow spec"
        )
        
        XCTAssertEqual(
            GitHubOAuthConfig.accessTokenURL,
            "/login/oauth/access_token",
            "Access token endpoint must match GitHub's OAuth spec"
        )
        
        XCTAssertEqual(
            GitHubOAuthConfig.apiBaseURL,
            "https://api.github.com",
            "API base URL must be GitHub's official API URL"
        )
        
        print("✅ OAuth endpoint configuration validated")
    }
    
    func testOAuthTimingConfiguration() {
        // Validate polling configuration is within GitHub's recommended limits
        XCTAssertGreaterThanOrEqual(
            GitHubOAuthConfig.pollingInterval,
            5,
            "Polling interval must be at least 5 seconds per GitHub's rate limiting"
        )
        
        XCTAssertLessThanOrEqual(
            GitHubOAuthConfig.pollingInterval, 
            15,
            "Polling interval should not exceed 15 seconds for good user experience"
        )
        
        XCTAssertGreaterThan(
            GitHubOAuthConfig.maxPollingAttempts,
            0,
            "Must have a positive maximum number of polling attempts"
        )
        
        // Ensure total polling time is reasonable (5-15 minutes)
        let totalPollingTime = GitHubOAuthConfig.pollingInterval * GitHubOAuthConfig.maxPollingAttempts
        XCTAssertGreaterThanOrEqual(
            totalPollingTime,
            300, // 5 minutes
            "Total polling time should be at least 5 minutes"
        )
        
        XCTAssertLessThanOrEqual(
            totalPollingTime,
            900, // 15 minutes  
            "Total polling time should not exceed 15 minutes"
        )
        
        print("✅ OAuth timing configuration validated")
        print("   Polling interval: \(GitHubOAuthConfig.pollingInterval) seconds")
        print("   Max attempts: \(GitHubOAuthConfig.maxPollingAttempts)")
        print("   Total timeout: \(totalPollingTime) seconds (\(totalPollingTime/60) minutes)")
    }
    
    func testClientIDConfiguration() {
        // Validate Client ID format (GitHub OAuth app Client IDs start with specific prefixes)
        let clientID = GitHubOAuthConfig.clientID
        
        XCTAssertFalse(
            clientID.isEmpty,
            "OAuth Client ID must be configured"
        )
        
        // GitHub OAuth app Client IDs have specific format patterns
        XCTAssertTrue(
            clientID.starts(with: "Ov") || clientID.starts(with: "Iv"),
            "GitHub OAuth app Client ID should start with 'Ov' (OAuth apps) or 'Iv' (GitHub apps). Current: '\(clientID)'"
        )
        
        // Client ID should be reasonable length (GitHub's are typically 20-21 characters)
        XCTAssertGreaterThanOrEqual(
            clientID.count,
            15,
            "Client ID seems too short, check configuration"
        )
        
        XCTAssertLessThanOrEqual(
            clientID.count,
            30,
            "Client ID seems too long, check configuration"
        )
        
        print("✅ OAuth Client ID configuration validated")
        print("   Client ID: \(clientID)")
    }
    
    // MARK: - Scope Coverage Tests
    
    func testScopeCoverageForHarbingerFeatures() {
        // Test that our scopes cover all Harbinger features
        
        // Repository access (required for listing repos and workflow access)
        XCTAssertTrue(
            GitHubOAuthConfig.scopes.contains("repo") || GitHubOAuthConfig.scopes.contains("public_repo"),
            "Harbinger needs repository access to read workflow runs"
        )
        
        // If we only have public_repo, warn about limitations
        if GitHubOAuthConfig.scopes.contains("public_repo") && !GitHubOAuthConfig.scopes.contains("repo") {
            print("⚠️  Warning: Using 'public_repo' scope only - private repositories will not be accessible")
        }
        
        print("✅ OAuth scopes cover required Harbinger features")
    }
    
    func testHistoricalScopeIssues() {
        // Test against known problematic scopes that caused issues
        
        let problematicScopes = [
            "workflow",      // Invalid scope that caused our bug
            "actions",       // Not a valid GitHub scope
            "workflows",     // Not a valid GitHub scope  
            "github_actions" // Not a valid GitHub scope
        ]
        
        for problematicScope in problematicScopes {
            XCTAssertFalse(
                GitHubOAuthConfig.scopes.contains(problematicScope),
                """
                Problematic scope '\(problematicScope)' found in configuration.
                
                This scope caused authentication failures in the past.
                For GitHub Actions access, use 'repo' scope instead.
                """
            )
        }
        
        print("✅ No historically problematic scopes detected")
    }
}