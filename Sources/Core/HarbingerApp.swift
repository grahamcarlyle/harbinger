import Cocoa

public class HarbingerApp {
    
    private let appDelegate: AppDelegate
    
    public init() {
        print("🚀 Starting Harbinger...")
        
        // Create the app delegate
        self.appDelegate = AppDelegate()
        
        // Set the app delegate
        NSApplication.shared.delegate = appDelegate
        
        print("📊 App delegate configured, ready to run...")
    }
    
    public func run() {
        print("🎯 Starting application...")
        NSApplication.shared.run()
    }
}