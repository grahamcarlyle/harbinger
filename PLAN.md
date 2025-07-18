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
- **Authentication**: GitHub OAuth
- **Data Storage**: UserDefaults for configuration

### 2. Core Components

#### 2.1 Status Bar Manager
- `NSStatusBar` integration
- Custom status item with colored icon
- Click handler for dropdown menu

#### 2.2 GitHub API Client
- Workflow runs endpoint integration (`/repos/{owner}/{repo}/actions/runs`)
- OAuth token management with automatic refresh
- Rate limiting management
- Error handling for API failures

#### 2.3 Authentication Manager
- GitHub OAuth flow implementation
- Token storage and refresh (Keychain)
- Custom URL scheme handling (`harbinger://auth`)

#### 2.4 Configuration Manager
- Repository list management
- Polling interval settings
- Workflow filtering options

#### 2.5 Data Models
```swift
struct Repository {
    let owner: String
    let name: String
    let workflows: [String]? // Optional specific workflows
}

struct WorkflowStatus {
    let name: String
    let status: String // "success", "failure", "in_progress"
    let url: String
    let lastUpdated: Date
}

struct AuthToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}
```

## Implementation Phases

### Phase 1: Core Infrastructure
1. **Xcode Project Setup**
   - Create new macOS app project
   - Configure Info.plist for status bar app
   - Set up custom URL scheme for OAuth
   - Register GitHub OAuth App

2. **Basic Status Bar**
   - Implement NSStatusItem
   - Create simple green/red icon system
   - Basic click handler

3. **OAuth Authentication**
   - Implement OAuth flow with browser redirect
   - Handle custom URL scheme callbacks
   - Token storage in Keychain
   - Automatic token refresh

### Phase 2: Core Functionality
1. **GitHub API Integration**
   - Implement GitHub API client with OAuth
   - Test with single repository
   - Handle authentication errors

2. **Configuration System**
   - Repository management interface
   - Settings persistence

3. **Status Monitoring**
   - Periodic polling mechanism
   - Status aggregation logic
   - Icon state management

### Phase 3: User Interface
1. **Authentication UI**
   - "Connect to GitHub" button
   - OAuth flow progress indication
   - Account connection status

2. **Status Dropdown**
   - Workflow list with statuses
   - Clickable links to GitHub
   - Status timestamps
   - Refresh button

3. **Settings Interface**
   - Repository management
   - Polling interval configuration

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

## GitHub OAuth Integration

### OAuth App Registration
- Create GitHub OAuth App in developer settings
- Set Authorization callback URL: `harbinger://auth`
- Note Client ID and Client Secret

### OAuth Flow
1. **Authorization Request**
   - Open browser to `https://github.com/login/oauth/authorize`
   - Parameters: `client_id`, `scope`, `redirect_uri`
   - Scopes: `repo` (private repos) or `public_repo` (public only)

2. **Authorization Code Exchange**
   - Handle redirect to `harbinger://auth?code=...`
   - Exchange code for access token
   - Store tokens securely in Keychain

3. **Token Refresh**
   - Monitor token expiration
   - Automatic refresh using refresh token
   - Re-authenticate if refresh fails

### Required API Endpoints
- `GET /repos/{owner}/{repo}/actions/runs` - Get workflow runs
- `GET /repos/{owner}/{repo}/actions/workflows` - Get available workflows
- `GET /user` - Verify token validity

### Rate Limiting
- Standard GitHub API limits: 5000 requests/hour
- Implement exponential backoff
- Cache results to minimize API calls

## Authentication

### GitHub OAuth
- **User Experience**: Click "Login with GitHub" → browser opens → authorize → done
- **Benefits**: Familiar flow, no manual token creation
- **Implementation**: Custom URL scheme, secure token storage

## Configuration Structure

### Repository Configuration
```json
{
  "repositories": [
    {
      "owner": "username",
      "name": "repo-name",
      "workflows": ["CI", "Deploy"] // Optional filter
    }
  ],
  "settings": {
    "pollInterval": 300, // seconds
    "showNotifications": true
  },
  "auth": {
    "tokens": "stored_in_keychain"
  }
}
```

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
- Validate OAuth state parameter
- Handle token expiration gracefully
- Secure Client Secret storage

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

## Testing Strategy

### Unit Tests
- GitHub API client functionality
- OAuth token management
- Status aggregation logic
- Configuration management

### Integration Tests
- End-to-end OAuth flow
- GitHub API integration
- Error handling scenarios
- Token refresh logic

### Manual Testing
- Various repository configurations
- Network connectivity issues
- OAuth token expiration
- Browser-based authentication flow

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

