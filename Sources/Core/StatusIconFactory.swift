import AppKit
import Foundation

/// Shared utility for creating status bar icons with consistent design
public class StatusIconFactory {
    
    public enum WorkflowStatus: String, CaseIterable {
        case unknown, passing, failing, running, runningAfterSuccess, runningAfterFailure
    }
    
    public static func createStatusIcon(for status: WorkflowStatus) -> NSImage {
        switch status {
        case .unknown:
            return createSimpleStatusIcon(symbolName: "questionmark.circle", status: status)
        case .passing:
            return createSimpleStatusIcon(symbolName: "checkmark.circle", status: status)
        case .failing:
            return createSimpleStatusIcon(symbolName: "xmark.circle", status: status)
        case .running:
            return createSimpleStatusIcon(symbolName: "play.circle", status: status)
        case .runningAfterSuccess:
            return createCombinedStatusIcon(baseSymbol: "checkmark.circle", overlaySymbol: "circle.fill", status: status)
        case .runningAfterFailure:
            return createCombinedStatusIcon(baseSymbol: "xmark.circle", overlaySymbol: "circle.fill", status: status)
        }
    }
    
    private static func createSimpleStatusIcon(symbolName: String, status: WorkflowStatus) -> NSImage {
        let description = "\(status)"
        guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) else {
            return createFallbackStatusIcon(for: status)
        }
        
        // Since we always pass tintColor: nil, we only use template images
        baseImage.isTemplate = true
        return baseImage
    }
    
    private static func createCombinedStatusIcon(baseSymbol: String, overlaySymbol: String, status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Clear background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw base symbol (checkmark.circle or xmark.circle)
        if let baseImage = NSImage(systemSymbolName: baseSymbol, accessibilityDescription: "\(status)") {
            let baseRect = NSRect(x: 0, y: 0, width: 16, height: 16)
            baseImage.draw(in: baseRect)
        }
        
        // Draw small overlay symbol (circle.fill) in bottom-right corner
        if let overlayImage = NSImage(systemSymbolName: overlaySymbol, accessibilityDescription: "running") {
            let overlaySize: CGFloat = 6
            let overlayRect = NSRect(x: size.width - overlaySize - 1, 
                                   y: 1, 
                                   width: overlaySize, 
                                   height: overlaySize)
            overlayImage.draw(in: overlayRect)
        }
        
        image.unlockFocus()
        image.isTemplate = true
        
        return image
    }
    
    private static func createFallbackStatusIcon(for status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(x: 2, y: 2, width: 12, height: 12)
        let path = NSBezierPath(ovalIn: rect)
        
        NSColor.black.setFill()
        path.fill()
        
        image.unlockFocus()
        image.isTemplate = true
        
        return image
    }
}