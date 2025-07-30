import HarbingerCore
import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    private func getSemanticColor(for status: StatusIconFactory.WorkflowStatus) -> NSColor {
        switch status {
        case .unknown:
            return NSColor.secondaryLabelColor
        case .passing:
            return NSColor.systemGreen
        case .failing:
            return NSColor.systemRed
        case .running:
            return NSColor.systemBlue
        case .runningAfterSuccess:
            return NSColor.systemGreen
        case .runningAfterFailure:
            return NSColor.systemRed
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        createIconDisplayWindow()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func createIconDisplayWindow() {
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 600, height: 450),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered,
                         defer: false)
        window.title = "Harbinger Status Icons"
        window.center()
        
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(containerView)
        
        let titleLabel = NSTextField(labelWithString: "Harbinger Status Bar Icons")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 400, width: 300, height: 30)
        containerView.addSubview(titleLabel)
        
        let statusStates: [(StatusIconFactory.WorkflowStatus, String, String)] = [
            (.unknown, "Unknown", "Gray question mark - initial state"),
            (.passing, "Passing", "Green checkmark - all workflows successful"),
            (.failing, "Failing", "Clear red X in circle - workflows failed"),
            (.running, "Running", "Blue play button - first workflow run"),
            (.runningAfterSuccess, "Running after Success", "Green checkmark with small circle indicator - workflows running, last completed successfully"),
            (.runningAfterFailure, "Running after Failure", "Red X with small circle indicator - workflows running, last completed with failures")
        ]
        
        let startY: CGFloat = 350
        let rowHeight: CGFloat = 55
        
        for (index, (status, title, description)) in statusStates.enumerated() {
            let y = startY - CGFloat(index) * rowHeight
            
            let icon = StatusIconFactory.createStatusIcon(for: status)
            let iconView = NSImageView(frame: NSRect(x: 30, y: y, width: 32, height: 32))
            iconView.image = icon
            
            // Apply appropriate tinting for template images
            if #available(macOS 10.14, *) {
                iconView.contentTintColor = getSemanticColor(for: status)
            }
            
            containerView.addSubview(iconView)
            
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            titleLabel.frame = NSRect(x: 80, y: y + 8, width: 150, height: 20)
            titleLabel.isBezeled = false
            titleLabel.isEditable = false
            titleLabel.backgroundColor = NSColor.clear
            containerView.addSubview(titleLabel)
            
            let descLabel = NSTextField(labelWithString: description)
            descLabel.font = NSFont.systemFont(ofSize: 12)
            descLabel.textColor = NSColor.secondaryLabelColor
            descLabel.frame = NSRect(x: 240, y: y + 8, width: 340, height: 20)
            descLabel.isBezeled = false
            descLabel.isEditable = false
            descLabel.backgroundColor = NSColor.clear
            containerView.addSubview(descLabel)
        }
        
        window.makeKeyAndOrderFront(nil)
    }
}

// Create and run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()