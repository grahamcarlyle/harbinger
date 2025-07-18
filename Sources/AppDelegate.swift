import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarManager: StatusBarManager?
    
    override init() {
        super.init()
        print("🚀 AppDelegate: Initializing...")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 Harbinger is starting...")
        
        // Force the app to stay running
        NSApp.setActivationPolicy(.accessory)
        print("📱 Set activation policy to accessory")
        
        // Initialize status bar
        statusBarManager = StatusBarManager()
        print("📊 Status bar manager initialized")
        
        // Check if already authenticated
        if GitHubOAuthConfig.isConfigured {
            print("✅ Already authenticated - access token found")
            // TODO: Validate token and start monitoring
        } else {
            print("❌ Not authenticated - need to connect to GitHub")
        }
        
        print("🎯 Harbinger should now be visible in menu bar")
        
        // Force the app to stay active
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔄 Checking status bar after 1 second...")
            if let statusItem = self.statusBarManager?.debugStatusItem {
                print("✅ Status item exists")
                if let button = statusItem.button {
                    print("✅ Status button exists")
                    print("🔍 Button title: '\(button.title)'")
                    print("🔍 Button image: \(button.image != nil ? "exists" : "nil")")
                } else {
                    print("❌ Status button is nil")
                }
            } else {
                print("❌ Status item is nil")
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up if needed
        print("Harbinger is shutting down")
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - URL Handling (for future OAuth callback if needed)
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle URL schemes if needed in the future
        for url in urls {
            print("Received URL: \(url)")
        }
    }
}