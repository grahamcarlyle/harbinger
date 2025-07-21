# GitHub Actions Status Bar Monitor - Implementation Plan

## Overview
Create a macOS status bar application that monitors GitHub Action workflows from specified repositories and displays their status with a color-coded indicator.

## Core Requirements
- **Status Indicator**: Green (all workflows passing) / Red (some workflows failing)
- **Click Action**: Show dropdown with workflow summaries and links to GitHub
- **Repository Support**: Both private and public repositories
- **Real-time Updates**: Periodic polling for workflow status

## Technical Architecture

### 1. Technology Stack
- **Language**: Swift (native macOS development)
- **Framework**: AppKit for status bar integration
- **HTTP Client**: URLSession for GitHub API calls
- **Authentication**: OAuth App with Device Flow
- **Data Storage**: UserDefaults for configuration

### 2. Core Components (Updated Architecture)

#### 2.1 Project Structure ✅ IMPLEMENTED
- **HarbingerCore Library**: Core business logic, API clients, models, authentication
- **HarbingerApp Executable**: Minimal entry point that imports and uses HarbingerCore
- **Comprehensive Test Suite**: Unit tests covering all major components

#### 2.2 Status Bar Manager ✅ IMPLEMENTED
- `NSStatusBar` integration with colored status indicators
- Custom status item with green/red/yellow/white icons
- Click handler for dropdown menu with OAuth integration
- Copy-to-clipboard functionality for device codes

#### 2.3 GitHub API Client ✅ IMPLEMENTED
- Multiple endpoint support: `/repos/{owner}/{repo}/actions/runs`, `/repos/{owner}/{repo}/actions/workflows`, `/user/repos`, `/user/orgs`, `/orgs/{org}/repos`
- OAuth Bearer token authentication with fallback to unauthenticated requests
- Automatic pagination support for repository lists (fetches all pages, handles 400+ repositories)
- Organization repository support with comprehensive coverage
- Comprehensive error handling (network, auth, rate limiting, API errors)
- Automatic JSON snake_case conversion and robust response parsing
- Network client retention to prevent callback deallocation bugs

#### 2.4 Authentication Manager ✅ IMPLEMENTED
- OAuth Device Flow implementation with copy button
- Device code generation, user verification, and user-controlled token exchange
- Secure token storage in macOS Keychain with proper retention
- Secure access token storage in macOS Keychain
- Authentication state management and error handling

#### 2.5 Data Models ✅ IMPLEMENTED
```swift
// Core GitHub API Models
public struct Repository: Codable {
    let name: String
    let fullName: String
    let owner: RepositoryOwner
    let private: Bool
    let htmlUrl: String
    // ... additional fields with automatic snake_case conversion
}

public struct WorkflowRun: Codable {
    let id: Int
    let name: String?
    let status: String // "completed", "in_progress", "queued"
    let conclusion: String? // "success", "failure", "cancelled"
    let htmlUrl: String
    let headSha: String
    // ... comprehensive GitHub API fields
    
    var statusColor: WorkflowRunStatus {
        // Computed property for UI status indication
    }
}

public enum WorkflowRunStatus {
    case success, failure, running, unknown
    // Color-coded status with emoji indicators
}

// Additional models: WorkflowsResponse, Workflow, HeadCommit, etc.
```

## Implementation Phases

### Phase 1: Core Infrastructure ✅ COMPLETED
1. **Xcode Project Setup** ✅
   - ✅ Create new macOS app project (Swift Package Manager)
   - ✅ Configure Info.plist for status bar app
   - ✅ Register OAuth App with Device Flow enabled
   - ✅ Configure OAuth App Client ID in code

2. **Basic Status Bar** ✅
   - ✅ Implement NSStatusItem
   - ✅ Create simple green/red icon system
   - ✅ Basic click handler with dropdown menu

3. **OAuth Device Flow Authentication** ✅
   - ✅ Implement OAuth Device Flow
   - ✅ Device code generation and user verification
   - ✅ Token polling and retrieval
   - ✅ Secure access token storage in Keychain

### Phase 2: Core Functionality ✅ COMPLETED
1. **GitHub API Integration** ✅
   - ✅ Implement GitHub API client with OAuth token authentication
   - ✅ Support for both authenticated and unauthenticated requests (public repos)
   - ✅ Test with public repositories (actions/runner-images, microsoft/TypeScript)
   - ✅ Handle authentication errors, rate limiting, and API failures
   - ✅ Comprehensive error types and logging
   - ✅ Automatic snake_case to camelCase JSON conversion

2. **Architecture Improvements** ✅
   - ✅ Restructure to library + executable pattern (HarbingerCore + HarbingerApp)
   - ✅ Move all business logic to HarbingerCore library
   - ✅ Create minimal executable entry point
   - ✅ Enable comprehensive unit testing

3. **Data Models & Testing** ✅
   - ✅ Complete GitHub API models (Repository, WorkflowRun, Workflow, etc.)
   - ✅ Comprehensive unit test suite (12 tests covering all major components)
   - ✅ Real API integration tests with public repositories
   - ✅ Performance testing and error handling validation
   - ✅ Support for XCTest framework with proper toolchain configuration

### Phase 3: User Interface
1. **Repository Selection Interface**
   - Repository management interface for monitoring specific repos
   - Add/remove repositories from monitoring list
   - Settings persistence and configuration

2. **Workflow Status Display**
   - Display real workflow statuses in status bar menu
   - Workflow list with statuses, timestamps, and clickable GitHub links
   - Status aggregation logic and icon state management
   - Refresh button and real-time updates

3. **Background Monitoring**
   - Periodic polling mechanism for workflow status
   - Background processing and notification system
   - Efficient API usage with caching and rate limiting

### Phase 4: Polish & Features
1. **Advanced Features**
   - Workflow filtering by name/branch
   - Custom polling intervals
   - Notification system for status changes

2. **Error Handling**
   - Network connectivity issues
   - Authentication failures
   - Rate limiting responses
   - OAuth token expiration

3. **Performance Optimization**
   - Efficient API usage
   - Background processing
   - Memory management

## OAuth Device Flow Integration

### OAuth App Registration
- Create OAuth App in developer settings
- Enable Device Flow in OAuth App settings
- Set required scopes: `repo` (access to private/public repositories)
- Note Client ID (no client secret needed)

### OAuth Device Flow Authentication
1. **Device Code Request**
   - App requests device and user verification codes
   - Receives authorization URL for user verification
   - Display user code and verification URL

2. **User Verification**
   - User visits https://github.com/login/device
   - Enters the user verification code
   - Authorizes the application

3. **User-Controlled Token Exchange**
   - User clicks "Continue" when authorization is complete
   - App makes single token exchange request
   - Receives access token upon success
   - No complex polling or timer management needed

4. **Token Management**
   - Store access token securely in Keychain
   - Handle token refresh (if supported)
   - Automatic re-authentication when needed

### Required API Endpoints
- `POST /login/device/code` - Request device and user verification codes
- `POST /login/oauth/access_token` - Poll for access token
- `GET /repos/{owner}/{repo}/actions/runs` - Get workflow runs
- `GET /repos/{owner}/{repo}/actions/workflows` - Get available workflows
- `GET /user/repos` - Get user's accessible repositories

### Rate Limiting
- Standard GitHub API limits: 5000 requests/hour
- Implement exponential backoff
- Cache results to minimize API calls

## Authentication

### OAuth Device Flow
- **User Experience**: Launch Harbinger → click "Connect to GitHub" → enter code in browser → done
- **Benefits**: No client secrets, no manual setup, secure OAuth flow
- **Implementation**: Device codes, user verification, access token storage

## Configuration Structure

### Repository Configuration
```json
{
  "repositories": [
    {
      "owner": "username",
      "name": "repo-name",
      "workflows": ["CI", "Deploy"]
    }
  ],
  "settings": {
    "pollInterval": 300,
    "showNotifications": true
  },
  "auth": {
    "tokens": "stored_in_keychain"
  }
}
```

**Note**: `workflows` array is optional for filtering specific workflows, `pollInterval` is in seconds, tokens are stored securely in Keychain.

## User Experience Flow

### Initial Setup
1. User launches app
2. Sees "Connect to GitHub" button
3. Clicks button → browser opens to GitHub OAuth
4. User authorizes app
5. Redirects back to app, authenticated
6. User adds repositories to monitor

### Normal Operation
- App polls GitHub API every 5 minutes
- Updates status bar icon color
- Shows summary on click

### Interaction
- Click status bar → dropdown appears
- Each workflow shows: name, status, last run time
- Click workflow → opens GitHub page in browser
- Settings accessible from dropdown

## Development Considerations

### Security
- Store OAuth tokens in Keychain (never in plain text)
- Store Client Secret in Keychain using KeychainHelper
- Store Client ID in UserDefaults (not sensitive)
- Validate OAuth state parameter
- Handle token expiration gracefully

### Performance
- Background queue for API calls
- Efficient polling (only fetch recent runs)
- Cache workflow metadata
- Minimize OAuth refresh calls

### User Interface
- Native macOS design patterns
- Accessibility support
- Dark mode compatibility
- Loading states during OAuth flow

## Testing Strategy ✅ IMPLEMENTED

### Unit Tests ✅ IMPLEMENTED
- **12 comprehensive unit tests** covering all major components
- **GitHub API client functionality**: Real API integration tests with public repositories
- **Model decoding tests**: JSON parsing with snake_case conversion validation
- **Authentication state management**: OAuth configuration and token handling
- **Performance testing**: API response time measurements
- **Error handling validation**: Network errors, rate limiting, invalid repositories

### Test Infrastructure ✅ IMPLEMENTED
- **XCTest Framework**: Full unit test suite with proper Xcode toolchain integration
- **Library Architecture Testing**: Enabled by HarbingerCore library structure
- **Real API Testing**: Tests against live GitHub repositories (actions/runner-images, microsoft/TypeScript)
- **Mock Data Testing**: Comprehensive JSON response validation
- **Command Line Testing**: `swift test`

### Test Coverage
- ✅ **GitHubClient**: API communication, authentication, error handling
- ✅ **Models**: All GitHub API response structures with snake_case conversion
- ✅ **Authentication**: OAuth token state and configuration checks
- ✅ **Performance**: API response time benchmarking
- ✅ **Error Scenarios**: Invalid repositories, network failures, rate limiting

## Deployment

### GitHub OAuth App Setup
- Register OAuth app in GitHub developer settings
- Configure redirect URI: `harbinger://auth`
- Manage Client ID/Secret securely

### Distribution Options
1. **Direct Distribution** - Standalone .app file
2. **Mac App Store** - Sandboxed version (OAuth restrictions)
3. **Homebrew Cask** - Package manager distribution

### Code Signing
- Developer ID for direct distribution
- App Store certificates for MAS
- Notarization for macOS Gatekeeper

## Future Enhancements

### Advanced Features
- Multiple GitHub accounts support
- Organization-wide monitoring
- Custom status icons/themes
- Workflow run logs preview
- Branch-specific monitoring

### Authentication Improvements
- GitHub App authentication (organization installs)
- SSO integration for enterprise
- Multi-account management

### Platform Expansion
- Menu bar app for Windows/Linux
- Web dashboard interface
- Mobile companion app

## Estimated Timeline

- **Phase 1**: 1-2 weeks (OAuth setup adds complexity)
- **Phase 2**: 2-3 weeks  
- **Phase 3**: 2-3 weeks (UI for OAuth flow)
- **Phase 4**: 1-2 weeks

**Total**: 6-10 weeks for complete implementation

