import Foundation
import AppKit

/// Utility class for detecting test environment and configuring appropriate test behavior
class TestEnvironment {
    
    // MARK: - Environment Detection
    
    /// Detects if tests are running in a CI environment
    static func isRunningInCI() -> Bool {
        let ciEnvironmentVariables = [
            "CI",                    // Generic CI flag
            "GITHUB_ACTIONS",        // GitHub Actions
            "JENKINS_URL",           // Jenkins
            "TRAVIS",                // Travis CI
            "CIRCLECI",              // Circle CI
            "BUILDKITE",             // Buildkite
            "GITLAB_CI"              // GitLab CI
        ]
        
        return ciEnvironmentVariables.contains { ProcessInfo.processInfo.environment[$0] != nil }
    }
    
    /// Checks if GUI/graphics access is available
    static func hasGUIAccess() -> Bool {
        // Check if we can access NSWorkspace (simpler approach for CI detection)
        return NSWorkspace.shared.frontmostApplication != nil
    }
    
    /// Determines if full GUI tests should run
    static func shouldRunFullGUITests() -> Bool {
        return !isRunningInCI() && hasGUIAccess()
    }
    
    // MARK: - Test Setup Helpers
    
    /// Logs the current test environment mode
    static func logTestMode() {
        if shouldRunFullGUITests() {
            print("🖥️ Running full GUI tests with AppKit components")
        } else {
            print("🤖 Running in CI/headless mode - testing logic without full GUI")
        }
    }
    
    /// Sets up graphics context for GUI tests if needed
    static func setupGraphicsContextIfNeeded() {
        guard shouldRunFullGUITests() else { return }
        
        // Set up graphics context for testing NSImage creation
        // This prevents crashes when testing AppKit graphics code
        if NSGraphicsContext.current == nil {
            let testImage = NSImage(size: NSSize(width: 1, height: 1))
            testImage.lockFocus()
            // Graphics context is now available for the test session
            testImage.unlockFocus()
        }
    }
    
    // MARK: - Conditional Test Execution
    
    /// Executes a closure only if full GUI tests should run
    static func runGUITest<T>(_ block: () throws -> T) rethrows -> T? {
        guard shouldRunFullGUITests() else { return nil }
        return try block()
    }
    
    /// Executes a closure only if running in headless/CI mode
    static func runHeadlessTest<T>(_ block: () throws -> T) rethrows -> T? {
        guard !shouldRunFullGUITests() else { return nil }
        return try block()
    }
}