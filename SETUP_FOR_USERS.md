# Setup Instructions for Users

## Quick Setup (30 seconds)

No GitHub App installation needed - just authorize Harbinger directly!

### Step 1: Launch Harbinger

1. Download and launch the Harbinger app
2. On first launch, you'll see:

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

### Step 2: Device Authorization

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

### Step 3: Repository Selection

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