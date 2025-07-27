import Cocoa

public class HarbingerApp {
    
    private let appDelegate: AppDelegate
    
    public init() {
        StatusBarDebugger.shared.log(.lifecycle, "Starting Harbinger...")
        
        // Create the app delegate
        self.appDelegate = AppDelegate()
        
        // Set the app delegate
        NSApplication.shared.delegate = appDelegate
        
        StatusBarDebugger.shared.log(.lifecycle, "App delegate configured, ready to run...")
    }
    
    public func run() {
        StatusBarDebugger.shared.log(.lifecycle, "Starting application...")
        NSApplication.shared.run()
    }
}