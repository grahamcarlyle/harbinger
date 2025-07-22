import Cocoa

public class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarManager: StatusBarManager?
    
    // MARK: - App Lifecycle
    
    override init() {
        super.init()
        print("🚀 AppDelegate: Initializing...")
    }
    
    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 Harbinger is starting...")
        
        // Configure as menu bar only app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the status bar interface
        statusBarManager = StatusBarManager()
        print("📊 Status bar manager created, app ready...")
    }
    
    public func applicationWillTerminate(_ aNotification: Notification) {
        print("🔄 Harbinger is shutting down...")
        
        // Clean up resources if needed
        statusBarManager = nil
    }
    
    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - URL Handling
    
    public func application(_ application: NSApplication, open urls: [URL]) {
        // Handle URL schemes for future OAuth callback support if needed
        for url in urls {
            print("📱 AppDelegate: Received URL: \(url)")
            // Future: Could handle harbinger:// URLs for OAuth callbacks
        }
    }
    
    // MARK: - Menu Handling
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle when user clicks the dock icon (if activation policy changes)
        return false
    }
}