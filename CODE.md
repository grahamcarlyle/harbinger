# Harbinger Code Architecture

## Overview

Harbinger is a native macOS status bar application written in Swift that monitors GitHub Actions workflow statuses and displays them as colored indicators in the system menu bar. The app uses OAuth Device Flow for authentication and provides a clean interface for repository management.

## Project Structure

### Swift Package Manager Architecture

The project uses Swift Package Manager (SPM) with a **library + executable** pattern for better testability and modular design:

```
Harbinger/
├── Package.swift                    # SPM configuration (like package.json)
├── Sources/
│   ├── Core/                       # HarbingerCore library (business logic)
│   └── App/                        # HarbingerApp executable (entry point)
└── Tests/
    └── HarbingerTests/             # Unit tests
```

**Why this pattern?** 
- The executable target (`HarbingerApp`) is minimal and just imports the library
- All business logic lives in the library (`HarbingerCore`) 
- Libraries can be unit tested, executables cannot in Swift
- This enables comprehensive testing coverage

### Core Components

## 1. Application Entry Point

**File: `Sources/App/main.swift`**

```swift
import HarbingerCore

let app = HarbingerApp()
app.run()
```

This is the minimal executable entry point that creates and runs the main application class.

**File: `Sources/Core/HarbingerApp.swift`**

The main application class that:
- Creates and configures the `AppDelegate`
- Sets up the `NSApplication` delegate pattern
- Starts the application event loop

**File: `Sources/Core/AppDelegate.swift`**

The `NSApplicationDelegate` that handles macOS app lifecycle events:
- `applicationDidFinishLaunching`: Configures app as menu bar only (`.accessory` policy) and creates `StatusBarManager`
- `applicationWillTerminate`: Cleanup when app shuts down
- `applicationShouldHandleReopen`: Handle dock icon clicks (currently disabled for menu bar apps)
- `application(_:open:)`: URL scheme handling for future OAuth callback support

**macOS Concept:** `NSApplicationDelegate` is the standard macOS pattern for handling app lifecycle events, similar to application delegates in iOS or main classes in other frameworks.

## 2. Status Bar Management

**File: `Sources/Core/StatusBarManager.swift`**

This is the heart of the macOS integration. Key concepts:

### NSStatusBar Integration
```swift
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
```

**macOS Concept:** `NSStatusBar` is the system menu bar (top of screen). Apps can add `NSStatusItem`s to display icons and menus.

### Status Icon Creation
The app creates colored circle icons programmatically:
```swift
private func createStatusIcon(for status: WorkflowStatus) -> NSImage {
    // Creates colored circles: Green (passing), Red (failing), Yellow (running), Gray (unknown)
    // Uses NSBezierPath to draw circles with NSColor fills
}
```

**Swift/macOS Concept:** `NSImage` is like a bitmap image. `NSBezierPath` is a vector drawing API similar to HTML5 Canvas or SVG paths.

### Menu System
```swift
statusItem?.menu = menu  // Assigns dropdown menu to status bar icon
```

When users click the status bar icon, it shows:
- Repository status summaries
- Individual workflow statuses with clickable GitHub links
- Control buttons (Settings, Refresh, Quit)

## 3. GitHub API Integration

**File: `Sources/Core/GitHubClient.swift`**

### HTTP Client Architecture
```swift
private let session = URLSession.shared  // HTTP client (like fetch/axios)
```

**Swift Concept:** `URLSession` is Swift's built-in HTTP client, similar to `fetch()` in JavaScript or `requests` in Python.

### API Endpoints Used
- `GET /repos/{owner}/{repo}/actions/runs` - Get workflow run history
- `GET /user/repos` - Get user's repositories  
- `GET /user/orgs` - Get user's organizations
- `GET /orgs/{org}/repos` - Get organization repositories

### JSON Decoding Strategy
```swift
decoder.keyDecodingStrategy = .convertFromSnakeCase
```

**Swift Concept:** Swift uses `Codable` protocol for JSON serialization (like `@JsonProperty` in Java). The `convertFromSnakeCase` automatically converts `snake_case` JSON keys to `camelCase` Swift properties.

### Robust Decoding Approach
The models only include essential fields to prevent decoding failures:

```swift
public struct WorkflowRun: Codable {
    let name: String?           // Workflow display name
    let status: String          // "in_progress", "queued", "completed" 
    let conclusion: String?     // "success", "failure", "cancelled"
    let htmlUrl: String         // GitHub link
    let headSha: String         // Commit SHA
    
    // 20+ other fields commented out for robustness
}
```

**Why?** GitHub API responses can vary and include extra fields. By only decoding what we need, the app is resilient to API changes.

## 4. OAuth Authentication

**File: `Sources/Core/AuthManager.swift`**

### OAuth Device Flow Implementation
This implements GitHub's OAuth Device Flow (designed for devices without web browsers):

1. **Request Device Code:**
   ```
   POST https://github.com/login/device/code
   Response: { device_code, user_code, verification_uri }
   ```

2. **User Authorization:**
   - App shows user code (e.g., "ABCD-1234")  
   - User goes to https://github.com/login/device
   - User enters code and authorizes

3. **Token Exchange:**
   ```
   POST https://github.com/login/oauth/access_token
   Response: { access_token }
   ```

### User-Controlled Flow
Instead of complex polling timers, the app uses a stateful approach:
- Show device code with "Continue" button
- User clicks "Continue" after authorizing on GitHub
- App makes single token exchange request

### Secure Token Storage
```swift
GitHubOAuthConfig.accessToken  // Stored in macOS Keychain
```

**macOS Concept:** Keychain is the system password manager. It provides encrypted storage for sensitive data like API tokens.

## 5. Repository and Workflow Monitoring

**File: `Sources/Core/RepositoryManager.swift`**

### Repository Discovery
The app fetches repositories from multiple sources:
- User's personal repositories (`/user/repos`)
- Organizations the user belongs to (`/user/orgs`) 
- All repositories in each organization (`/orgs/{org}/repos`)

### Pagination Handling
```swift
private func fetchAllRepositories(url: String, page: Int = 1, ...)
```

GitHub API returns 100 repositories per page. The app recursively fetches all pages to get complete repository lists (can be 400+ repositories for active developers).

### Deduplication
```swift
let uniqueRepos = Array(Set(allRepositories.map { $0.fullName }))
```

Since users may have access to the same repository through multiple paths (personal + organization), the app deduplicates by full name (e.g., "owner/repo-name").

**File: `Sources/Core/WorkflowMonitor.swift`**

### Workflow Status Logic
```swift
public var overallStatus: WorkflowRunStatus {
    // Base status on the most recent workflow run (not all recent runs)
    let mostRecentWorkflow = workflows.first!
    return mostRecentWorkflow.status
}
```

**Key Decision:** The app shows status based on the **most recent** workflow run, not all recent runs. This matches GitHub's repository badge behavior.

### Status Calculation Pipeline
1. `WorkflowMonitor` fetches workflow runs for each monitored repository
2. `RepositoryWorkflowStatus` calculates per-repository status from workflow runs
3. Overall app status aggregated from all repository statuses
4. `StatusBarManager` updates the colored icon based on overall status

### Refresh Strategy
- **Automatic:** Every 5 minutes via `Timer.scheduledTimer`
- **Manual:** User can click "Refresh" button
- **On startup:** Immediate refresh when app launches

## 6. User Interface Components

### Repository Settings Window
**File: `Sources/Core/RepositorySettingsWindow.swift`**

**macOS Concept:** `NSWindow` is a desktop window (like a dialog box). `NSTableView` is like an HTML table for displaying data.

Features:
- Browse all available repositories (personal + organization)
- Add/remove repositories from monitoring
- Manual repository entry via text field
- Real-time repository validation

### Debugging System
**Files: `StatusBarDebugger.swift`, `StatusBarStateVerifier.swift`, `StatusBarSelfHealer.swift`**

Comprehensive debugging system that:
- **Logs** all operations to `~/Documents/HarbingerLogs/`
- **Verifies** status bar state health
- **Self-heals** by recreating broken status bar items
- **Reports** system state for troubleshooting

## 7. Data Models

**File: `Sources/Core/Models.swift`**

### Core Models Architecture
```swift
// GitHub API Response Models
struct Repository: Codable          // Repository metadata
struct WorkflowRun: Codable         // Individual workflow run
struct WorkflowRunsResponse: Codable // API response wrapper

// Application Models  
struct MonitoredRepository          // User-selected repository for monitoring
struct RepositoryWorkflowStatus     // Repository + its workflow statuses
struct WorkflowRunSummary          // Simplified workflow run for display

// Status Enums
enum WorkflowRunStatus {            // .success, .failure, .running, .unknown
    case success, failure, running, unknown
}
```

### Data Flow
1. **Raw GitHub Data** → `WorkflowRun` (via JSON decoding)
2. **Processed Data** → `WorkflowRunSummary` (simplified for display)  
3. **Repository Status** → `RepositoryWorkflowStatus` (repository + workflows)
4. **UI Display** → Status bar icon + menu items

## 8. Configuration and Persistence

### OAuth Configuration
**File: `Sources/Core/GitHubOAuthConfig.swift`**

```swift
static let clientID = "Ov23li..."        // Public OAuth app ID (safe to embed)
static let scopes = ["repo"]             // Minimal required permissions
static var accessToken: String?          // Retrieved from Keychain
```

### Repository Persistence
```swift
UserDefaults.standard.set(data, forKey: "MonitoredRepositories")
```

**macOS Concept:** `UserDefaults` is like browser localStorage - key-value storage for app preferences.

## 9. Error Handling Strategy

### Network Resilience
- HTTP status code handling (401 auth, 403 rate limit, 404 not found)
- Automatic retry logic for transient failures
- Graceful degradation when repositories are inaccessible

### JSON Decoding Robustness  
- Essential fields only in models
- Optional fields for non-critical data
- Detailed error logging for debugging

### Authentication Recovery
- Automatic re-authentication prompts when tokens expire
- Clear error messages for authorization failures
- State preservation during auth flows

## Key Design Decisions

1. **Library + Executable Pattern:** Enables comprehensive unit testing
2. **Minimal JSON Models:** Only essential fields for API resilience
3. **Most Recent Run Status:** Matches GitHub badge behavior vs. aggregate status
4. **User-Controlled OAuth:** Eliminates complex polling timers
5. **Comprehensive Debugging:** Essential for GUI app troubleshooting
6. **Keychain Security:** Proper credential storage for production use

## Threading Model

**Swift/macOS Concept:** Like most UI frameworks, macOS requires UI updates on the main thread.

```swift
DispatchQueue.main.async {
    // Update UI elements (status bar icon, menus)
}
```

- **Network requests:** Background threads
- **JSON processing:** Background threads  
- **UI updates:** Main thread only
- **Timer callbacks:** Main thread

## Build and Distribution

### Swift Package Manager
```swift
// Package.swift
.executableTarget(name: "HarbingerApp", dependencies: ["HarbingerCore"])
.target(name: "HarbingerCore")
```

### Commands
```bash
swift build      # Compile
swift run        # Run in development
swift test       # Run unit tests
./create_app.sh  # Create distributable .app bundle
```

The final deliverable is a `.app` bundle that users can drag to their Applications folder - standard macOS app distribution.