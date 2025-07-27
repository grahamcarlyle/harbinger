import Foundation
import AppKit
@testable import HarbingerCore

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
    
    /// Sets up the test environment and logging
    static func setupTestEnvironment() {
        // Disable console logging to keep test output clean
        // This will eliminate most of the debug noise during tests
        StatusBarDebugger.shared.disableConsoleLogging()
        
        // Set verbosity based on environment
        if ProcessInfo.processInfo.environment["VERBOSE_TESTS"] != "1" {
            verboseTestOutput = false
        }
        
        // Log test mode (this will still show since it's intentional test info)
        logTestMode()
    }
    
    /// Tears down the test environment
    static func tearDownTestEnvironment() {
        // Re-enable console logging for normal app usage
        StatusBarDebugger.shared.enableConsoleLogging()
    }
    
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
    
    // MARK: - Test-Aware Output
    
    /// Controls whether test debug output should be shown
    public static var verboseTestOutput: Bool = {
        // Check for explicit verbose flag
        if ProcessInfo.processInfo.environment["VERBOSE_TESTS"] == "1" {
            return true
        }
        // Default to quiet in CI, verbose locally
        return !isRunningInCI()
    }()
    
    /// Test-aware print that respects verbosity settings
    static func testPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard verboseTestOutput else { return }
        
        let output = items.map { "\($0)" }.joined(separator: separator)
        Swift.print(output, terminator: terminator)
    }
}