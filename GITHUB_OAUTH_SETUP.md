# GitHub OAuth App Setup Instructions

## For App Developers

You need to create a GitHub OAuth App once that all users can authorize.

### Step 1: Create OAuth App

1. Go to [GitHub Settings → Developer settings → OAuth Apps](https://github.com/settings/developers)
2. Click **"New OAuth App"**
3. Fill in the form:
   - **Application name**: `Harbinger`
   - **Homepage URL**: `https://github.com/yourusername/harbinger`
   - **Application description**: `macOS status bar monitor for GitHub Actions workflows`
   - **Authorization callback URL**: `http://localhost` (required field, but not used for Device Flow)

### Step 2: Enable Device Flow

1. After creating the OAuth App, go to the app settings
2. **IMPORTANT**: Check the **"Enable Device Flow"** checkbox
3. Click **"Update application"**

### Step 3: Note Your App Details

After creating the app, note:
- **Client ID** (shown on the app page, looks like `Ov23li...`)
- **Client Secret** (NOT needed for Device Flow - ignore this)

### Step 4: Update Code

Update `GitHubOAuthConfig.swift`:
```swift
static let clientID = "Ov23liABC123XYZ" // Your actual Client ID
```

### Step 5: Test the Flow

1. Build and run your app
2. Click "Connect to GitHub"
3. App should display a device code
4. Go to https://github.com/login/device
5. Enter the code and authorize
6. App should receive the access token

## Why OAuth Device Flow is Better

✅ **No client secrets** - Device Flow doesn't require client secrets
✅ **No private keys** - No sensitive credentials in the app
✅ **Secure by design** - OAuth handles all security
✅ **Simple distribution** - Just embed the public Client ID
✅ **User-friendly** - Standard OAuth authorization flow

## Security Benefits

- **Client ID is public** - Safe to embed in the app
- **No secrets to protect** - Device Flow eliminates client secrets
- **GitHub handles security** - OAuth flow is battle-tested
- **Revokable access** - Users can revoke access anytime

## Required Scopes

The app will request minimal permissions:
- `repo` - Access to private and public repositories (read-only operations for monitoring workflows)

**Note**: GitHub's OAuth scopes are coarse-grained. The `repo` scope is the minimal scope that allows reading private repositories and their Actions workflows. While this scope technically grants write access, Harbinger only performs read operations.

## Rate Limiting

- **5000 requests/hour** per authenticated user
- **Device Flow has built-in rate limiting** for polling
- **Respect the polling interval** returned by GitHub

## Testing

Test the OAuth flow by:
1. Running the app in debug mode
2. Clicking "Connect to GitHub"
3. Following the device authorization flow
4. Verifying the app receives an access token
5. Testing API calls with the token

## Distribution

When distributing your app:
1. **Client ID is embedded** in the app (public, safe)
2. **Users authorize directly** through OAuth Device Flow
3. **No setup required** for users
4. **No sensitive data** in the app bundle

## Troubleshooting

### "Device Flow not enabled" Error
- Make sure you checked "Enable Device Flow" in OAuth App settings
- This must be enabled for Device Flow to work

### "Invalid Client ID" Error
- Double-check the Client ID in your code
- Make sure it matches the one from GitHub settings

### "Polling too frequently" Error
- Respect the polling interval returned by GitHub
- Default to 5 seconds if not specified