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
            return createSimpleStatusIcon(symbolName: "questionmark.circle", tintColor: nil, status: status)
        case .passing:
            return createSimpleStatusIcon(symbolName: "checkmark.circle", tintColor: nil, status: status)
        case .failing:
            return createCrossIcon(status: status)
        case .running:
            return createPlayIcon(status: status)
        case .runningAfterSuccess:
            return createAnimatedCheckmarkIcon(status: status)
        case .runningAfterFailure:
            return createAnimatedCrossIcon(status: status)
        }
    }
    
    private static func createSimpleStatusIcon(symbolName: String, tintColor: NSColor?, status: WorkflowStatus) -> NSImage {
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
    
    private static func createDirectDrawnIcon(color: NSColor, status: WorkflowStatus) -> NSImage {
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
    
    private static func createCrossIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        NSColor.systemRed.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        NSColor.systemRed.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the cross (X) inside
        let crossColor = NSColor.systemRed
        crossColor.setStroke()
        
        let crossPath = NSBezierPath()
        crossPath.lineWidth = 2.0
        crossPath.lineCapStyle = .round
        
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
    
    private static func createPlayIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        NSColor.systemBlue.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        NSColor.systemBlue.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the play triangle (▶️) inside  
        let trianglePath = NSBezierPath()
        NSColor.systemBlue.setFill()
        
        let centerX: CGFloat = 9
        let centerY: CGFloat = 9
        let triangleSize: CGFloat = 6
        
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
    
    private static func createAnimatedCheckmarkIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background with light green fill
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        NSColor.systemGreen.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        NSColor.systemGreen.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the checkmark (✓) inside
        let checkColor = NSColor.systemGreen
        checkColor.setStroke()
        
        let checkPath = NSBezierPath()
        checkPath.lineWidth = 2.0
        checkPath.lineCapStyle = .round
        checkPath.lineJoinStyle = .round
        
        let centerX: CGFloat = 9
        let centerY: CGFloat = 9
        let checkSize: CGFloat = 5
        
        checkPath.move(to: NSPoint(x: centerX - checkSize/2, y: centerY - 1))
        checkPath.line(to: NSPoint(x: centerX, y: centerY - checkSize/2))
        checkPath.line(to: NSPoint(x: centerX + checkSize/2, y: centerY + 2))
        
        checkPath.stroke()
        
        // Add running indicator in corner
        let indicatorSize: CGFloat = 6
        let indicatorRect = NSRect(x: size.width - indicatorSize - 1, y: 1, 
                                 width: indicatorSize, height: indicatorSize)
        let indicatorPath = NSBezierPath(ovalIn: indicatorRect)
        
        let indicatorColor = NSColor.systemGreen.blended(withFraction: 0.4, of: .white) ?? NSColor.systemGreen
        indicatorColor.setFill()
        indicatorPath.fill()
        
        NSColor.white.setStroke()
        indicatorPath.lineWidth = 0.5
        indicatorPath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private static func createAnimatedCrossIcon(status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw circle background
        let circleRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        NSColor.systemRed.withAlphaComponent(0.2).setFill()
        circlePath.fill()
        
        NSColor.systemRed.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        // Draw the cross (X) inside
        let crossColor = NSColor.systemRed
        crossColor.setStroke()
        
        let crossPath = NSBezierPath()
        crossPath.lineWidth = 2.0
        crossPath.lineCapStyle = .round
        
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
        
        let indicatorColor = NSColor.systemRed.blended(withFraction: 0.4, of: .white) ?? NSColor.systemRed
        indicatorColor.setFill()
        indicatorPath.fill()
        
        NSColor.white.setStroke()
        indicatorPath.lineWidth = 0.5
        indicatorPath.stroke()
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private static func createFallbackStatusIcon(for status: WorkflowStatus) -> NSImage {
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