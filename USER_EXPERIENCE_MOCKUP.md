# Harbinger - User Experience Mockup

## 1. Status Bar Icon States

### All Workflows Passing (Green)
```
macOS Menu Bar: [🔋] [📶] [🔊] [🟢] [🕐 2:30 PM]
                                 ^
                            Harbinger icon
```

### Some Workflows Failing (Red)
```
macOS Menu Bar: [🔋] [📶] [🔊] [🔴] [🕐 2:30 PM]
                                 ^
                            Harbinger icon
```

### Loading/Checking (Yellow)
```
macOS Menu Bar: [🔋] [📶] [🔊] [🟡] [🕐 2:30 PM]
                                 ^
                            Harbinger icon
```

## 2. Initial Setup Flow

### Step 1: First Launch (OAuth Device Flow)
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

### Step 2: Device Authorization Code
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
│                                         │
│  Code expires in 14:23                  │
└─────────────────────────────────────────┘
```

### Step 3: Repository Selection
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

## 3. Main Dropdown Menu (Click on Status Bar Icon)

### When All Workflows Pass
```
┌─────────────────────────────────────────┐
│  ✅ All workflows passing               │
│  ─────────────────────────────────────  │
│                                         │
│  username/my-project                    │
│  ✅ CI/CD Pipeline    2m ago   →        │
│  ✅ Tests            5m ago   →        │
│                                         │
│  username/another-repo                  │
│  ✅ Build & Deploy   10m ago  →        │
│                                         │
│  ─────────────────────────────────────  │
│  🔄 Refresh                             │
│  ⚙️  Settings                           │
│  ❌ Quit Harbinger                      │
└─────────────────────────────────────────┘
```

### When Some Workflows Fail
```
┌─────────────────────────────────────────┐
│  ❌ 1 workflow failing                   │
│  ─────────────────────────────────────  │
│                                         │
│  username/my-project                    │
│  ❌ CI/CD Pipeline    2m ago   →        │
│  ✅ Tests            5m ago   →        │
│                                         │
│  username/another-repo                  │
│  ✅ Build & Deploy   10m ago  →        │
│                                         │
│  ─────────────────────────────────────  │
│  🔄 Refresh                             │
│  ⚙️  Settings                           │
│  ❌ Quit Harbinger                      │
└─────────────────────────────────────────┘
```

### When Workflows Are Running
```
┌─────────────────────────────────────────┐
│  🔄 2 workflows running                  │
│  ─────────────────────────────────────  │
│                                         │
│  username/my-project                    │
│  🔄 CI/CD Pipeline    running  →        │
│  ✅ Tests            5m ago   →        │
│                                         │
│  username/another-repo                  │
│  🔄 Build & Deploy   running  →        │
│                                         │
│  ─────────────────────────────────────  │
│  🔄 Refresh                             │
│  ⚙️  Settings                           │
│  ❌ Quit Harbinger                      │
└─────────────────────────────────────────┘
```

## 4. Settings Window
```
┌─────────────────────────────────────────┐
│  Harbinger Settings                     │
│  ─────────────────────────────────────  │
│                                         │
│  Account:                               │
│  🟢 Connected as @username              │
│  [Disconnect]                           │
│                                         │
│  Repositories:                          │
│  ┌─────────────────────────────────────┐ │
│  │ username/my-project        [Remove] │ │
│  │ username/another-repo      [Remove] │ │
│  └─────────────────────────────────────┘ │
│  [Add Repository]                       │
│                                         │
│  Refresh Interval:                      │
│  ┌─────────────────────────────────────┐ │
│  │ Every 5 minutes            ▼       │ │
│  └─────────────────────────────────────┘ │
│                                         │
│  Notifications:                         │
│  ☑️ Show notifications for failures     │
│  ☑️ Show notifications for recoveries   │
│                                         │
│  [Save Changes]  [Cancel]               │
└─────────────────────────────────────────┘
```

## 5. Notification Examples

### Failure Notification
```
┌─────────────────────────────────────────┐
│  Harbinger                              │
│  ─────────────────────────────────────  │
│  ❌ Workflow Failed                      │
│                                         │
│  CI/CD Pipeline in username/my-project  │
│  failed 2 minutes ago                   │
│                                         │
│  [View on GitHub]  [Dismiss]            │
└─────────────────────────────────────────┘
```

### Recovery Notification
```
┌─────────────────────────────────────────┐
│  Harbinger                              │
│  ─────────────────────────────────────  │
│  ✅ Workflow Recovered                   │
│                                         │
│  All workflows in username/my-project   │
│  are now passing                        │
│                                         │
│  [View on GitHub]  [Dismiss]            │
└─────────────────────────────────────────┘
```

## 6. Click-through Behavior

### Workflow Item Click
```
When user clicks "CI/CD Pipeline →":
1. Opens default browser
2. Navigates to GitHub workflow run page
3. URL: https://github.com/username/my-project/actions/runs/123456789
```

### Device Flow States
```
Authorization in progress:
"Harbinger: Connecting to GitHub..."

Authorization complete:
"Harbinger: 2 repos, 1 failing"
```

### Status Summary
```
Menu bar tooltip on hover:
"Harbinger: 2 repos, 1 failing"
```

## 7. Error States

### No Internet Connection
```
┌─────────────────────────────────────────┐
│  ⚠️  Connection Error                    │
│  ─────────────────────────────────────  │
│                                         │
│  Unable to connect to GitHub            │
│  Check your internet connection         │
│                                         │
│  Last updated: 10m ago                  │
│                                         │
│  [Retry]                                │
│  ⚙️  Settings                           │
│  ❌ Quit Harbinger                      │
└─────────────────────────────────────────┘
```

### Authentication Error
```
┌─────────────────────────────────────────┐
│  ⚠️  Authentication Error                │
│  ─────────────────────────────────────  │
│                                         │
│  GitHub OAuth access has been revoked   │
│  or expired                             │
│                                         │
│  [Reconnect to GitHub]                  │
│  ⚙️  Settings                           │
│  ❌ Quit Harbinger                      │
└─────────────────────────────────────────┘
```

## 8. Empty State (No Repositories)
```
┌─────────────────────────────────────────┐
│  📋 No repositories configured           │
│  ─────────────────────────────────────  │
│                                         │
│  Add repositories to start monitoring   │
│  their GitHub Actions workflows         │
│                                         │
│  [Add Repository]                       │
│  ⚙️  Settings                           │
│  ❌ Quit Harbinger                      │
└─────────────────────────────────────────┘
```

## Visual Design Notes

### Status Bar Icon
- **Green Circle (🟢)**: All workflows passing
- **Red Circle (🔴)**: One or more workflows failing  
- **Yellow Circle (🟡)**: Workflows running/loading
- **Gray Circle (⚫)**: Disconnected/error state

### Menu Design
- **Native macOS appearance**: Uses system fonts, colors, and spacing
- **Dark mode compatible**: Adapts to system appearance
- **Consistent with macOS HIG**: Follows Apple's design guidelines
- **Accessible**: Proper contrast ratios and keyboard navigation

### Interaction Patterns
- **Single click**: Opens dropdown menu
- **Option+click**: Opens settings directly
- **Hover**: Shows tooltip with summary
- **Keyboard shortcuts**: Arrow keys to navigate menu items