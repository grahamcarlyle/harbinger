import Cocoa

public class HarbingerApp {
    
    private let statusBarManager: StatusBarManager
    
    public init() {
        print("🚀 Starting Harbinger...")
        
        // Create and configure the application
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        
        // Create the status bar manager
        self.statusBarManager = StatusBarManager()
        
        print("📊 Status bar manager created, app ready...")
    }
    
    public func run() {
        print("🎯 Starting application...")
        NSApplication.shared.run()
    }
}