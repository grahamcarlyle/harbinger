# Setup Instructions for Users

## Quick Setup (30 seconds)

No GitHub App installation needed - just authorize Harbinger directly!

### Step 1: Download and Launch Harbinger

1. **Download**: Go to the [Releases page](../../releases) and download the latest `Harbinger.zip`
2. **Extract**: Double-click `Harbinger.zip` to extract `Harbinger.app`
3. **Install**: Right-click `Harbinger.app` and select "Open" (bypass Gatekeeper warning for unsigned apps)
4. **Optional**: Move `Harbinger.app` to your Applications folder
5. **Launch**: The app will appear in your menu bar (no dock icon)

### Step 2: First Launch

On first launch, you'll see:

```
┌─────────────────────────────────────────┐
│  Welcome to Harbinger                   │
│  ─────────────────────────────────────  │
│                                         │
│  Monitor your GitHub Actions workflows │
│  directly from your menu bar.          │
│                                         │
│  [Connect to GitHub]                    │
│                                         │
│  No setup required - just authorize!   │
└─────────────────────────────────────────┘
```

3. Click **"Connect to GitHub"**

### Step 3: Device Authorization

1. The app will show you a verification code:

```
┌─────────────────────────────────────────┐
│  GitHub Authorization                   │
│  ─────────────────────────────────────  │
│                                         │
│  1. Go to: https://github.com/login/device │
│                                         │
│  2. Enter this code: ABCD-1234          │
│                                         │
│  3. Authorize Harbinger                 │
│                                         │
│  4. Click "Continue" after authorizing  │
│                                         │
│  [Open GitHub]  [Copy Code]  [Continue] │
└─────────────────────────────────────────┘
```

2. Click **"Open GitHub"** or go to https://github.com/login/device
3. Enter the verification code shown in the app
4. Click **"Authorize"** on the GitHub page
5. Return to Harbinger and click **"Continue"** when you've completed authorization

### Step 4: Repository Selection

1. Choose which repositories to monitor:

```
┌─────────────────────────────────────────┐
│  Select Repositories to Monitor         │
│  ─────────────────────────────────────  │
│                                         │
│  Available repositories:                │
│  ☑️ username/my-project                  │
│  ☑️ organization/shared-repo             │
│  ☐ username/old-project                 │
│  ☐ organization/archived-repo           │
│                                         │
│  Includes personal and organization     │
│  repositories you have access to.       │
│                                         │
│  [Add Repository Manually...]           │
│                                         │
│  [Start Monitoring]                     │
└─────────────────────────────────────────┘
```

2. Click **"Start Monitoring"**
3. Done! The app will start monitoring your workflows

## System Requirements

- **macOS 13.0 or later** (Ventura, Sonoma, Sequoia)
- **Internet connection** for GitHub API access
- **GitHub account** with repositories containing Actions workflows

## About Unsigned Apps

Harbinger is currently distributed as an unsigned app for personal use. When you first open it:

1. **Security Warning**: macOS will show "Harbinger cannot be opened because it is from an unidentified developer"
2. **Solution**: Right-click `Harbinger.app` → Select "Open" → Click "Open" in the dialog
3. **One-time Setup**: After the first open, you can launch normally from Applications or menu bar
4. **Why Unsigned**: This avoids Apple Developer Program costs while providing the same functionality

This is normal for many open-source macOS apps and is completely safe for this codebase.

## What Gets Authorized

Harbinger requests permission to:
- **Read your repositories** (public and private, personal and organization)
- **Read GitHub Actions workflows** (status, run history)
- **Read workflow runs** (success, failure, in progress)
- **Access organization repositories** (for organizations you're a member of)

## Managing Access

You can manage Harbinger's access anytime:
1. Go to [GitHub Settings → Applications → Authorized OAuth Apps](https://github.com/settings/applications)
2. Find "Harbinger" in the list
3. Click "Revoke" to remove access
4. Or click the app name to review permissions

## Why This is Better

- ✅ **No manual setup** - Just click and authorize
- ✅ **No app installation** - Direct OAuth authorization
- ✅ **Secure** - Standard GitHub OAuth flow
- ✅ **Easy to revoke** - Standard OAuth app management
- ✅ **No client secrets** - Uses Device Flow (no secrets needed)

## Troubleshooting

### "Invalid Code" Error
- Make sure you entered the code exactly as shown
- Code is case-sensitive
- If code expired, restart the authorization process

### "Authorization Timeout" Error
- You have 15 minutes to complete authorization
- If it times out, click "Connect to GitHub" again

### Can't See Workflows
- Make sure the repository has GitHub Actions enabled
- Check that there are workflow files in `.github/workflows/`
- Verify you have read access to the repository