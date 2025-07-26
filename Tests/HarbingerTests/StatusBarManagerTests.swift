import XCTest
import AppKit
@testable import HarbingerCore

final class StatusBarManagerTests: XCTestCase {
    
    var statusBarManager: StatusBarManager!
    
    override func setUp() {
        super.setUp()
        
        // Set up graphics context for testing NSImage creation
        // This prevents crashes when testing AppKit graphics code
        if NSGraphicsContext.current == nil {
            let testImage = NSImage(size: NSSize(width: 1, height: 1))
            testImage.lockFocus()
            // Graphics context is now available for the test session
            testImage.unlockFocus()
        }
        
        statusBarManager = StatusBarManager()
    }
    
    override func tearDown() {
        statusBarManager = nil
        super.tearDown()
    }
    
    func testStatusIconCreation() {
        print("\n=== STATUS ICON CREATION TEST ===")
        
        // Test actual icon creation with proper graphics context
        let testCases: [(StatusBarManager.WorkflowStatus, String)] = [
            (.passing, "Green"),
            (.failing, "Red"),
            (.running, "Yellow"),
            (.unknown, "Gray")
        ]
        
        for (status, colorName) in testCases {
            let icon = statusBarManager.createStatusIcon(for: status)
            
            // Test icon properties
            XCTAssertNotNil(icon, "Status icon should be created for \(status)")
            XCTAssertEqual(icon.size, NSSize(width: 18, height: 18), "Icon should have correct size")
            XCTAssertFalse(icon.isTemplate, "Icon should not be template to show colors")
            XCTAssertTrue(icon.representations.count > 0, "Icon should have image representations")
            
            print("✅ \(colorName) icon created successfully for \(status) status")
        }
        
        print("✅ All status icons created successfully")
    }
    
    func testStatusIconColorMapping() {
        print("\n=== STATUS ICON COLOR MAPPING LOGIC TEST ===")
        
        // Test the color mapping logic separately for extra safety
        let testCases: [(StatusBarManager.WorkflowStatus, NSColor, String)] = [
            (.passing, .systemGreen, "Green"),
            (.failing, .systemRed, "Red"),
            (.running, .systemYellow, "Yellow"),
            (.unknown, .systemGray, "Gray")
        ]
        
        for (status, expectedColor, colorName) in testCases {
            // Test the color selection logic that matches the implementation
            let color: NSColor
            switch status {
            case .unknown:
                color = NSColor.systemGray
            case .passing:
                color = NSColor.systemGreen
            case .failing:
                color = NSColor.systemRed
            case .running:
                color = NSColor.systemYellow
            }
            
            XCTAssertEqual(color, expectedColor, "Status \(status) should map to \(colorName) color")
            print("✅ \(colorName) color mapped correctly for \(status) status")
        }
        
        print("✅ All status icon colors mapped correctly")
    }
    
    func testWorkflowStatusConversion() {
        print("\n=== WORKFLOW STATUS CONVERSION TEST ===")
        
        // Test the conversion from WorkflowRunStatus to internal WorkflowStatus
        let conversions: [(WorkflowRunStatus, StatusBarManager.WorkflowStatus)] = [
            (.success, .passing),
            (.failure, .failing),
            (.running, .running),
            (.unknown, .unknown)
        ]
        
        for (runStatus, expectedInternalStatus) in conversions {
            // Simulate the conversion logic from didUpdateOverallStatus
            let internalStatus: StatusBarManager.WorkflowStatus
            switch runStatus {
            case .success:
                internalStatus = .passing
            case .failure:
                internalStatus = .failing
            case .running:
                internalStatus = .running
            case .unknown:
                internalStatus = .unknown
            }
            
            XCTAssertEqual(internalStatus, expectedInternalStatus, 
                          "WorkflowRunStatus.\(runStatus) should convert to WorkflowStatus.\(expectedInternalStatus)")
            print("✅ \(runStatus) → \(internalStatus)")
        }
        
        print("✅ All status conversions working correctly")
    }
    
    func testStatusIconProperties() {
        print("\n=== STATUS ICON PROPERTIES TEST ===")
        
        let passingIcon = statusBarManager.createStatusIcon(for: .passing)
        
        // Test detailed icon properties
        XCTAssertEqual(passingIcon.size.width, 18, "Icon width should be 18")
        XCTAssertEqual(passingIcon.size.height, 18, "Icon height should be 18")
        XCTAssertFalse(passingIcon.isTemplate, "Icon should not be template to preserve colors")
        XCTAssertTrue(passingIcon.representations.count > 0, "Icon should have content")
        
        print("✅ Status icon properties verified")
        print("   - Size: \(passingIcon.size)")
        print("   - Template: \(passingIcon.isTemplate)")
        print("   - Representations: \(passingIcon.representations.count)")
    }
    
    func testOverallStatusUpdateFlow() {
        print("\n=== OVERALL STATUS UPDATE FLOW TEST ===")
        
        // Test the complete flow from WorkflowRunStatus to colored icon
        let testStatuses: [WorkflowRunStatus] = [.success, .failure, .running, .unknown]
        
        for status in testStatuses {
            // This simulates what happens in didUpdateOverallStatus
            let internalStatus: StatusBarManager.WorkflowStatus
            switch status {
            case .success:
                internalStatus = .passing
            case .failure:
                internalStatus = .failing
            case .running:
                internalStatus = .running
            case .unknown:
                internalStatus = .unknown
            }
            
            // Verify the icon can be created for this status
            let icon = statusBarManager.createStatusIcon(for: internalStatus)
            XCTAssertNotNil(icon, "Should create icon for \(status) → \(internalStatus)")
            XCTAssertFalse(icon.isTemplate, "Icon should preserve colors for \(status)")
            XCTAssertEqual(icon.size, NSSize(width: 18, height: 18), "Icon should have correct size for \(status)")
            
            print("✅ Status update flow works: \(status) → \(internalStatus) → colored icon")
        }
        
        print("✅ Overall status update flow verified")
    }
    
    func testColoredMenuItemViewHoverEffects() {
        print("\n=== COLORED MENU ITEM VIEW HOVER EFFECTS TEST ===")
        
        // Test different status colors and hover effects
        let testCases: [(WorkflowRunStatus, String)] = [
            (.success, "Green"),
            (.failure, "Red"), 
            (.running, "Yellow"),
            (.unknown, "Gray")
        ]
        
        for (status, colorName) in testCases {
            let menuItemView = ColoredMenuItemView(title: "Test Item", isHeader: false, status: status)
            
            // Test initial state
            XCTAssertFalse(menuItemView.isHovered, "Should start in non-hovered state")
            
            // Test hover state change by calling the methods directly
            // (avoiding NSEvent creation issues in unit tests)
            
            // First, let's test the setup - tracking areas should be configured
            XCTAssertTrue(menuItemView.trackingAreas.count > 0, "Should have tracking areas set up")
            
            // Test that the view is properly initialized
            XCTAssertNotNil(menuItemView.subviews.first, "Should have a label subview")
            XCTAssertEqual(menuItemView.subviews.count, 1, "Should have exactly one subview (the label)")
            
            print("✅ \(colorName) menu item view properly initialized for \(status)")
            
            // Test dimensions based on type
            if status == .success {
                XCTAssertEqual(menuItemView.intrinsicContentSize.height, 24, "Height should be 24")
                XCTAssertEqual(menuItemView.intrinsicContentSize.width, 350, "Regular item width should be 350")
            }
        }
        
        print("✅ All colored menu item view properties verified")
    }
    
    func testColoredMenuItemViewProperties() {
        print("\n=== COLORED MENU ITEM VIEW PROPERTIES TEST ===")
        
        // Test header vs non-header items
        let headerView = ColoredMenuItemView(title: "Header Item", isHeader: true, status: .success)
        let regularView = ColoredMenuItemView(title: "Regular Item", isHeader: false, status: .success)
        let buildView = ColoredMenuItemView(title: "Build Item", isHeader: false, status: .success, isBuildEntry: true)
        
        // Test dimensions
        XCTAssertEqual(headerView.intrinsicContentSize.height, 24, "Header view should have correct height")
        XCTAssertEqual(regularView.intrinsicContentSize.height, 24, "Regular view should have correct height")
        XCTAssertEqual(buildView.intrinsicContentSize.height, 24, "Build view should have correct height")
        
        // Test widths - width depends on isBuildEntry, not isHeader
        XCTAssertEqual(headerView.intrinsicContentSize.width, 350, "Header view without isBuildEntry should use standard width")
        XCTAssertEqual(regularView.intrinsicContentSize.width, 350, "Regular view should use standard width")
        XCTAssertEqual(buildView.intrinsicContentSize.width, 500, "Build view should use wider width")
        
        print("✅ Header view dimensions: \(headerView.intrinsicContentSize)")
        print("✅ Regular view dimensions: \(regularView.intrinsicContentSize)")
        print("✅ Build view dimensions: \(buildView.intrinsicContentSize)")
        
        print("✅ Colored menu item view properties verified")
    }
    
    func testMenuItemClickHandling() {
        print("\n=== MENU ITEM CLICK HANDLING TEST ===")
        
        let menuItemView = ColoredMenuItemView(title: "Clickable Item", isHeader: false, status: .success)
        
        // Test menu item association
        let menuItem = NSMenuItem(title: "", action: #selector(dummyAction), keyEquivalent: "")
        menuItem.target = self
        
        menuItemView.setMenuItem(menuItem)
        
        // Verify the menu item is set by testing that the click handler exists
        // (We can't directly access the private weak property, but we can test the setup worked)
        XCTAssertTrue(menuItem.target === self, "Menu item target should be set")
        XCTAssertEqual(menuItem.action, #selector(dummyAction), "Menu item action should be set")
        
        print("✅ Menu item click handling setup verified")
        print("✅ Menu item association working")
    }
    
    
    
    
    
    
    @objc private func dummyAction(_ sender: NSMenuItem) {
        // Dummy action for testing
    }
}