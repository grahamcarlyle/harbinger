# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Harbinger is a macOS status bar application that monitors GitHub Actions workflows and displays their status with color-coded indicators. It uses OAuth Device Flow authentication for seamless user experience and displays workflow statuses in a dropdown menu accessible from the menu bar.

## Development Environment

- **Language**: Swift 5.0
- **Target**: macOS 13.0+
- **Framework**: AppKit (native macOS)
- **Build System**: Xcode project
- **Package Manager**: Bun (for Node.js dependencies like Claude Code)

## Build Commands

```bash
# Open project in Xcode
open Harbinger.xcodeproj

# Build from command line
xcodebuild -project Harbinger.xcodeproj -scheme Harbinger -configuration Debug build

# Build for release
xcodebuild -project Harbinger.xcodeproj -scheme Harbinger -configuration Release build
```

## Core Architecture

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
3. **Planned Components** (from project.pbxproj):
   - `AppDelegate.swift` - App lifecycle management
   - `StatusBarManager.swift` - Menu bar integration and UI
   - `GitHubClient.swift` - GitHub API communication with OAuth tokens
   - `AuthManager.swift` - OAuth Device Flow authentication
   - `Models.swift` - Data structures for workflows and repositories

### Data Flow
1. User launches Harbinger and clicks "Connect to GitHub"
2. App initiates OAuth Device Flow and displays verification code
3. User enters code at https://github.com/login/device and authorizes
4. App polls GitHub API for workflow status using OAuth access tokens
5. Status aggregated and displayed as colored menu bar icon
6. Click reveals dropdown with detailed workflow information

## Key Configuration

### OAuth Configuration
- OAuth endpoints and scopes defined in `GitHubOAuthConfig`
- Required scopes: `repo`, `workflow`
- Client ID embedded in app (no client secret needed)
- Device Flow configuration for polling and timeouts

### Security Model
- Access tokens managed through `KeychainHelper` for secure storage
- OAuth tokens encrypted in macOS Keychain
- Device Flow eliminates need for client secrets
- No sensitive data in UserDefaults or plain text storage

## Development Notes

### GitHub API Integration
- Target endpoints: `/repos/{owner}/{repo}/actions/runs`
- Rate limiting: 5000 requests/hour per token
- Polling-based updates with configurable intervals

### User Experience
- Color-coded status: Green (passing), Red (failing), Yellow (running)
- Native macOS design patterns and dark mode support
- Clickable workflow items link to GitHub web interface

### Setup Requirements
Users simply launch Harbinger and click "Connect to GitHub" to start the OAuth Device Flow. The app displays a verification code that users enter at https://github.com/login/device to authorize access. No manual credential setup or app installation required.