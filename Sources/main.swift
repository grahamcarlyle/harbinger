import Cocoa

print("🚀 Starting Harbinger...")

// Create and configure the application
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Create the status bar manager
let statusBarManager = StatusBarManager()

print("📊 Status bar manager created, starting app...")

// Start the application
app.run()