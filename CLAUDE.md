# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Harbinger is a macOS status bar application that monitors GitHub Actions workflows and displays their status with color-coded indicators. It uses OAuth Device Flow authentication for seamless user experience and displays workflow statuses in a dropdown menu accessible from the menu bar.

## Development Environment

- **Language**: Swift 5.0
- **Target**: macOS 13.0+
- **Framework**: AppKit (native macOS)
- **Build System**: Swift Package Manager
- **Package Manager**: Bun (for Node.js dependencies like Claude Code)

## Build Commands

```bash
# Build the app
swift build

# Run the app
swift run

# Run unit tests including integration tests
swift test

# Create app bundle
./create_app.sh

# Run app bundle
open Harbinger.app

# Debug output (when running app bundle)
./Harbinger.app/Contents/MacOS/Harbinger > /tmp/harbinger.log 2>&1 &
cat /tmp/harbinger.log
```

## Core Architecture

### Project Structure
- **Library + Executable Pattern**: Core logic in `HarbingerCore` library, minimal executable in `HarbingerApp`
- **Targets**:
  - `HarbingerCore` (Sources/Core/): Business logic, API clients, models
  - `HarbingerApp` (Sources/App/): Minimal executable entry point
  - `HarbingerTests` (Tests/): Comprehensive unit test suite

### Status Bar Application Design
- **LSUIElement**: Configured as `true` in Info.plist to run as menu bar only app (no dock icon)
- **Bundle ID**: `com.harbinger.statusbar`

### Authentication Architecture
- **OAuth Device Flow**: Uses GitHub OAuth Device Flow with user authorization codes
- **Credential Storage**: 
  - Client ID embedded in app (public, no secret needed)
  - Access tokens stored in macOS Keychain via `KeychainHelper`
  - No client secrets required for Device Flow
- **Security**: Uses `KeychainHelper` class for secure token management

### Core Components Structure
1. **GitHubOAuthConfig**: Central configuration for OAuth credentials and endpoints
2. **KeychainHelper**: Secure storage utilities for access tokens
3. **Current Components** (in Sources/Core/):
   - `GitHubOAuthConfig.swift` - OAuth configuration and Keychain helpers ✅ **IMPLEMENTED**
   - `AuthManager.swift` - OAuth Device Flow authentication ✅ **IMPLEMENTED**
   - `StatusBarManager.swift` - Menu bar integration and UI ✅ **IMPLEMENTED**
   - `GitHubClient.swift` - GitHub API communication ✅ **IMPLEMENTED**
   - `Models.swift` - Data structures for workflows and repositories ✅ **IMPLEMENTED**
   - `HarbingerApp.swift` - Main application class ✅ **IMPLEMENTED**
4. **Executable** (in Sources/App/):
   - `main.swift` - App entry point and initialization ✅ **IMPLEMENTED**

### Data Flow
1. User launches Harbinger and clicks "Connect to GitHub"
2. App initiates OAuth Device Flow and displays verification code with copy button
3. User enters code at https://github.com/login/device and authorizes
4. App polls GitHub API for workflow status using OAuth access tokens
5. Status aggregated and displayed as colored menu bar icon
6. Click reveals dropdown with detailed workflow information

### GitHub API Integration
- **Endpoints**: 
  - `/repos/{owner}/{repo}/actions/runs` - Workflow runs for specific repository
  - `/repos/{owner}/{repo}/actions/workflows` - Available workflows for repository
  - `/user/repos` - User's personal repositories (paginated)
  - `/user/orgs` - User's organizations  
  - `/orgs/{org}/repos` - Organization repositories (paginated)
- **Authentication**: OAuth Bearer tokens with fallback to unauthenticated for public repos
- **Pagination**: Automatic pagination support for repository lists (100 per page, fetches all pages)
- **Rate Limiting**: 5000 requests/hour per token (unauthenticated: 60/hour per IP)
- **JSON Handling**: Automatic snake_case to camelCase conversion via `JSONDecoder.keyDecodingStrategy`
- **Error Handling**: Comprehensive error types for network, auth, rate limiting, and API errors
- **Repository Coverage**: Fetches repositories from both personal account and all organizations

## Key Configuration

### OAuth Configuration
- OAuth endpoints and scopes defined in `GitHubOAuthConfig`
- Required scopes: `repo` (access to private/public repositories and Actions workflows)
- Client ID embedded in app (no client secret needed)
- Device Flow configuration for polling and timeouts

### Security Model
- Access tokens managed through `KeychainHelper` for secure storage
- OAuth tokens encrypted in macOS Keychain
- Device Flow eliminates need for client secrets
- No sensitive data in UserDefaults or plain text storage

## Development Notes

### Testing Infrastructure
- **Unit Tests**: Comprehensive test suite covering API clients, models, and authentication
- **XCTest Framework**: Full integration with Swift Package Manager testing
- **OAuth Validation Tests**: Tests validate scopes against GitHub's official list
- **Client Retention Tests**: Prevents callback deallocation bugs by ensuring network clients are properly retained
- **Public API Testing**: Tests work against real GitHub repositories without authentication
- **Mock Testing**: JSON decoding tests with sample GitHub API responses
- **Performance Testing**: API response time measurements included
- **Pagination Testing**: Validates multi-page repository fetching and deduplication

### User Experience
- **Color-coded status**: Green (passing), Red (failing), Yellow (running), White (unknown)
- **Native macOS design patterns** with dark mode support
- **Clickable workflow items** link directly to GitHub web interface
- **Repository management**: Browse and select from all personal and organization repositories
- **Manual repository entry** with validation for repositories not in the main list
- **Real-time status updates** with periodic refresh and immediate feedback
- **Copy-to-clipboard functionality** for OAuth device codes during setup

### Setup Requirements
Users launch Harbinger and click "Connect to GitHub" to start the user-controlled OAuth Device Flow. The app displays a verification code and opens GitHub in the browser. After authorizing on GitHub, users click "Continue" in the app to complete authentication. The app then provides access to all repositories from the user's account and organizations for monitoring selection. No manual credential setup or app installation required.

## Current Status

**Phase 1 Complete** ✅
- OAuth Device Flow authentication fully implemented
- Status bar app with colored indicators working
- Secure token storage in macOS Keychain
- User-friendly authorization flow with copy button

**Phase 2 Complete** ✅
- GitHub API client with comprehensive error handling
- Support for both authenticated and unauthenticated requests
- Complete data models for workflows, repositories, and workflow runs
- Robust JSON decoding with automatic snake_case conversion
- Comprehensive unit test suite with 12 tests covering all major components
- Library + executable architecture for better testability

**Phase 3 Complete** ✅
- User-controlled OAuth flow replacing complex polling timers
- Repository selection interface with comprehensive organization support
- Automatic pagination for complete repository discovery (personal + org repos)
- Manual repository entry with validation and autocomplete
- Real-time workflow status monitoring and aggregation
- Status bar integration with colored indicators and detailed dropdown menu
- Periodic background refresh with configurable intervals
- Robust error handling and debugging infrastructure

**Current Features:**
- ✅ **Complete Repository Coverage**: Fetches all repositories from personal account and organizations (handles 400+ repos with pagination)
- ✅ **Organization Support**: Full support for organization repositories with proper permissions
- ✅ **Real-time Monitoring**: Active monitoring of selected repositories with workflow status updates
- ✅ **Network Client Reliability**: Fixed callback deallocation issues ensuring consistent API responses
- ✅ **Comprehensive Testing**: OAuth scope validation, pagination testing, and client retention verification