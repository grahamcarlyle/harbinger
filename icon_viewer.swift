#!/usr/bin/env swift

import AppKit
import Foundation

// Copy the essential StatusBarManager functionality here for icon viewing
class IconViewer {
    enum WorkflowStatus: String, CaseIterable {
        case unknown, passing, failing, running, runningAfterSuccess, runningAfterFailure
    }
    
    func createStatusIcon(for status: WorkflowStatus) -> NSImage {
        switch status {
        case .unknown:
            return createSimpleStatusIcon(symbolName: "questionmark.circle", tintColor: nil, status: status)
        case .passing:
            return createSimpleStatusIcon(symbolName: "checkmark.circle", tintColor: nil, status: status)
        case .failing:
            return createCrossIcon(status: status)
        case .running:
            return createPlayIcon(status: status)
        case .runningAfterSuccess:
            return createAnimatedStatusIcon(baseIcon: "checkmark.circle", tintColor: .systemGreen, status: status)
        case .runningAfterFailure:
            return createAnimatedCrossIcon(status: status)
        }
    }
    
    private func createSimpleStatusIcon(symbolName: String, tintColor: NSColor?, status: WorkflowStatus) -> NSImage {
        let description = "\(status)"
        guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) else {
            return createFallbackStatusIcon(for: status)
        }
        
        guard let tintColor = tintColor else {
            baseImage.isTemplate = true
            return baseImage
        }
        
        return createDirectDrawnIcon(color: tintColor, status: status)
    }
    
    private func createDirectDrawnIcon(color: NSColor, status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        color.setFill()
        circlePath.fill()
        
        let borderColor = color.blended(withFraction: 0.3, of: .black) ?? color
        borderColor.setStroke()
        circlePath.lineWidth = 0.5
        circlePath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func createCrossIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        // Use a light red background for the circle
        NSColor.systemRed.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        // Add circle border
        NSColor.systemRed.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the cross (X) inside
        let crossColor = NSColor.systemRed
        crossColor.setStroke()
        
        let crossPath = NSBezierPath()
        crossPath.lineWidth = 2.0
        crossPath.lineCapStyle = .round
        
        // Draw diagonal lines to form an X
        let inset: CGFloat = 5
        crossPath.move(to: NSPoint(x: 2 + inset, y: 2 + inset))
        crossPath.line(to: NSPoint(x: 16 - inset, y: 16 - inset))
        crossPath.move(to: NSPoint(x: 16 - inset, y: 2 + inset))
        crossPath.line(to: NSPoint(x: 2 + inset, y: 16 - inset))
        
        crossPath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func createPlayIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        // Use a light blue background for the circle
        NSColor.systemBlue.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        // Add circle border
        NSColor.systemBlue.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the play triangle (▶️) inside  
        let trianglePath = NSBezierPath()
        NSColor.systemBlue.setFill()
        
        // Create a right-pointing triangle centered in the circle
        let centerX: CGFloat = 9  // Center of 18px icon
        let centerY: CGFloat = 9
        let triangleSize: CGFloat = 6
        
        // Triangle points (pointing right)
        let leftPoint = NSPoint(x: centerX - triangleSize/2, y: centerY - triangleSize/2)
        let rightPoint = NSPoint(x: centerX + triangleSize/2, y: centerY)
        let bottomPoint = NSPoint(x: centerX - triangleSize/2, y: centerY + triangleSize/2)
        
        trianglePath.move(to: leftPoint)
        trianglePath.line(to: rightPoint)
        trianglePath.line(to: bottomPoint)
        trianglePath.close()
        
        trianglePath.fill()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func createAnimatedCrossIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        // Use a light red background for the circle
        NSColor.systemRed.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        // Add circle border
        NSColor.systemRed.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the cross (X) inside
        let crossColor = NSColor.systemRed
        crossColor.setStroke()
        
        let crossPath = NSBezierPath()
        crossPath.lineWidth = 2.0
        crossPath.lineCapStyle = .round
        
        // Draw diagonal lines to form an X
        let inset: CGFloat = 5
        crossPath.move(to: NSPoint(x: 2 + inset, y: 2 + inset))
        crossPath.line(to: NSPoint(x: 16 - inset, y: 16 - inset))
        crossPath.move(to: NSPoint(x: 16 - inset, y: 2 + inset))
        crossPath.line(to: NSPoint(x: 2 + inset, y: 16 - inset))
        
        crossPath.stroke()
        
        // Add running indicator in corner
        let indicatorSize: CGFloat = 6
        let indicatorRect = NSRect(x: size.width - indicatorSize - 1, y: 1, 
                                 width: indicatorSize, height: indicatorSize)
        let indicatorPath = NSBezierPath(ovalIn: indicatorRect)
        
        // Use a bright red for the indicator
        let indicatorColor = NSColor.systemRed.blended(withFraction: 0.4, of: .white) ?? NSColor.systemRed
        indicatorColor.setFill()
        indicatorPath.fill()
        
        // Add white border to indicator for visibility
        NSColor.white.setStroke()
        indicatorPath.lineWidth = 0.5
        indicatorPath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func createAnimatedStatusIcon(baseIcon: String, tintColor: NSColor, status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw the base icon (checkmark.circle, xmark.circle, or circle)
        if let baseImage = NSImage(systemSymbolName: baseIcon, accessibilityDescription: "\(status)") {
            let iconRect = NSRect(x: 1, y: 1, width: 16, height: 16)
            
            if baseIcon == "circle" {
                // For plain running state, draw a filled circle
                let circlePath = NSBezierPath(ovalIn: iconRect)
                tintColor.setFill()
                circlePath.fill()
                
                let borderColor = tintColor.blended(withFraction: 0.3, of: .black) ?? tintColor
                borderColor.setStroke()
                circlePath.lineWidth = 0.5
                circlePath.stroke()
            } else {
                // For checkmark.circle or xmark.circle, use the SF Symbol but tinted
                let coloredImage = baseImage.copy() as! NSImage
                coloredImage.lockFocus()
                tintColor.set()
                NSRect(origin: .zero, size: coloredImage.size).fill(using: .sourceAtop)
                coloredImage.unlockFocus()
                
                coloredImage.draw(in: iconRect)
            }
        }
        
        // Add a small pulsing indicator in the corner to show "running" state
        let indicatorSize: CGFloat = 6
        let indicatorRect = NSRect(x: size.width - indicatorSize - 1, y: 1, 
                                 width: indicatorSize, height: indicatorSize)
        let indicatorPath = NSBezierPath(ovalIn: indicatorRect)
        
        // Use a brighter version of the main color for the indicator
        let indicatorColor = tintColor.blended(withFraction: 0.4, of: .white) ?? tintColor
        indicatorColor.setFill()
        indicatorPath.fill()
        
        // Add white border to indicator for visibility
        NSColor.white.setStroke()
        indicatorPath.lineWidth = 0.5
        indicatorPath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func createCombinedStatusIcon(runningIcon: String, backgroundIcon: String, tintColor: NSColor, status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        let backgroundRect = NSRect(x: 1, y: 1, width: 16, height: 16)
        let backgroundPath = NSBezierPath(ovalIn: backgroundRect)
        
        let backgroundColor: NSColor
        if backgroundIcon == "checkmark.circle" {
            backgroundColor = NSColor.systemGreen
        } else if backgroundIcon == "circle.fill" {
            backgroundColor = NSColor.systemRed
        } else {
            backgroundColor = NSColor.systemGray
        }
        
        backgroundColor.withAlphaComponent(0.3).setFill()
        backgroundPath.fill()
        
        let runningSize: CGFloat = 8
        let runningRect = NSRect(x: size.width - runningSize - 1, y: size.height - runningSize - 1, 
                               width: runningSize, height: runningSize)
        let runningPath = NSBezierPath(ovalIn: runningRect)
        
        tintColor.setFill()
        runningPath.fill()
        
        let borderColor = tintColor.blended(withFraction: 0.3, of: .black) ?? tintColor
        borderColor.setStroke()
        runningPath.lineWidth = 0.5
        runningPath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func createFallbackStatusIcon(for status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(x: 3, y: 3, width: 12, height: 12)
        let path = NSBezierPath(ovalIn: rect)
        
        NSColor.black.setFill()
        path.fill()
        
        image.unlockFocus()
        image.isTemplate = true
        
        return image
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let iconViewer = IconViewer()
    
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
        
        let statusStates: [(IconViewer.WorkflowStatus, String, String)] = [
            (.unknown, "Unknown", "Gray question mark - initial state"),
            (.passing, "Passing", "Green checkmark - all workflows successful"),
            (.failing, "Failing", "Clear red X in circle - workflows failed"),
            (.running, "Running", "Blue play button - first workflow run"),
            (.runningAfterSuccess, "Running after Success", "Green checkmark with pulsing indicator"),
            (.runningAfterFailure, "Running after Failure", "Red X with pulsing indicator")
        ]
        
        let startY: CGFloat = 350
        let rowHeight: CGFloat = 55
        
        for (index, (status, title, description)) in statusStates.enumerated() {
            let y = startY - CGFloat(index) * rowHeight
            
            let icon = iconViewer.createStatusIcon(for: status)
            let iconView = NSImageView(frame: NSRect(x: 30, y: y, width: 32, height: 32))
            iconView.image = icon
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