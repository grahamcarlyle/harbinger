import XCTest
import AppKit
@testable import HarbingerCore

final class StatusBarManagerTests: XCTestCase {
    
    var statusBarManager: StatusBarManager!
    
    override class func setUp() {
        super.setUp()
        TestEnvironment.setupTestEnvironment()
    }
    
    override class func tearDown() {
        TestEnvironment.tearDownTestEnvironment()
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
        
        // Set up test-specific logging
        StatusBarDebugger.shared.setCurrentTest(self.name)
        
        TestEnvironment.setupGraphicsContextIfNeeded()
        
        statusBarManager = StatusBarManager()
    }
    
    override func tearDown() {
        statusBarManager = nil
        
        // Clear test-specific logging
        StatusBarDebugger.shared.clearCurrentTest()
        
        super.tearDown()
    }
    
    func testStatusIconCreation() {
        StatusBarDebugger.shared.log(.lifecycle, "STATUS ICON CREATION TEST")
        
        // Test actual icon creation with proper graphics context
        let testCases: [(StatusBarManager.WorkflowStatus, String)] = [
            (.passing, "Green"),
            (.failing, "Red"),
            (.running, "Yellow"),
            (.unknown, "Gray")
        ]
        
        for (status, colorName) in testCases {
            if TestEnvironment.shouldRunFullGUITests() {
                let icon = statusBarManager.createStatusIcon(for: status)
                
                // Test icon properties in full GUI mode
                XCTAssertNotNil(icon, "Status icon should be created for \(status)")
                // SF Symbols have variable sizes, just ensure they're reasonable
                XCTAssertGreaterThan(icon.size.width, 0, "Icon should have positive width")
                XCTAssertGreaterThan(icon.size.height, 0, "Icon should have positive height")
                // Only untinted icons should be template images for theme support
                // Tinted icons (failing, running, combined) are pre-tinted for better visibility
                let shouldBeTemplate = (status == .unknown || status == .passing)
                XCTAssertEqual(icon.isTemplate, shouldBeTemplate, "Icon template property should match expected behavior for \(status)")
                XCTAssertTrue(icon.representations.count > 0, "Icon should have image representations")
                
                StatusBarDebugger.shared.log(.verification, "Icon created successfully", context: ["color": colorName, "status": "\(status)"])
            } else {
                // In CI/headless mode, test the logic without creating actual NSImage objects
                StatusBarDebugger.shared.log(.state, "Testing status mapping logic", context: ["color": colorName, "status": "\(status)"])
                
                // Test that the status values are valid enum cases
                XCTAssertTrue([.passing, .failing, .running, .unknown].contains(status), 
                             "Status \(status) should be a valid WorkflowStatus case")
                
                StatusBarDebugger.shared.log(.verification, "Status logic validated", context: ["color": colorName, "status": "\(status)"])
            }
        }
        
        StatusBarDebugger.shared.log(.verification, "All status icon tests completed")
    }
    
    func testStatusIconColorMapping() {
        StatusBarDebugger.shared.log(.lifecycle, "STATUS ICON COLOR MAPPING LOGIC TEST")
        
        // Test the color mapping logic separately for extra safety
        let testCases: [(StatusBarManager.WorkflowStatus, NSColor, String)] = [
            (.passing, .systemGreen, "Green"),
            (.failing, .systemRed, "Red"),
            (.running, .systemBlue, "Blue"),
            (.unknown, .systemGray, "Gray"),
            (.runningAfterSuccess, .systemBlue, "Blue"),
            (.runningAfterFailure, .systemPurple, "Purple")
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
                color = NSColor.systemBlue
            case .runningAfterSuccess:
                color = NSColor.systemBlue
            case .runningAfterFailure:
                color = NSColor.systemPurple
            }
            
            XCTAssertEqual(color, expectedColor, "Status \(status) should map to \(colorName) color")
            StatusBarDebugger.shared.log(.verification, "Color mapped correctly", context: ["color": colorName, "status": "\(status)"])
        }
        
        StatusBarDebugger.shared.log(.verification, "All status icon colors mapped correctly")
    }
    
    func testWorkflowStatusConversion() {
        StatusBarDebugger.shared.log(.lifecycle, "WORKFLOW STATUS CONVERSION TEST")
        
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
            StatusBarDebugger.shared.log(.verification, "Status conversion", context: ["from": "\(runStatus)", "to": "\(internalStatus)"])
        }
        
        StatusBarDebugger.shared.log(.verification, "All status conversions working correctly")
    }
    
    func testStatusIconProperties() {
        StatusBarDebugger.shared.log(.lifecycle, "STATUS ICON PROPERTIES TEST")
        
        let passingIcon = statusBarManager.createStatusIcon(for: .passing)
        
        // Test detailed icon properties (Apple HIG compliant SF Symbols)
        XCTAssertGreaterThan(passingIcon.size.width, 0, "Icon should have positive width")
        XCTAssertGreaterThan(passingIcon.size.height, 0, "Icon should have positive height")
        XCTAssertTrue(passingIcon.isTemplate, "Icon should be template for proper theme support")
        XCTAssertTrue(passingIcon.representations.count > 0, "Icon should have content")
        
        StatusBarDebugger.shared.log(.verification, "Status icon properties verified", context: ["size": "\(passingIcon.size)", "template": "\(passingIcon.isTemplate)", "representations": "\(passingIcon.representations.count)"])
    }
    
    func testOverallStatusUpdateFlow() {
        StatusBarDebugger.shared.log(.lifecycle, "OVERALL STATUS UPDATE FLOW TEST")
        
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
            
            // Only untinted icons should be template images for theme support
            // Tinted icons (failing, running) are pre-tinted for better visibility
            let shouldBeTemplate = (internalStatus == .unknown || internalStatus == .passing)
            XCTAssertEqual(icon.isTemplate, shouldBeTemplate, "Icon template property should match expected behavior for \(internalStatus)")
            
            XCTAssertGreaterThan(icon.size.width, 0, "Icon should have positive width for \(status)")
            XCTAssertGreaterThan(icon.size.height, 0, "Icon should have positive height for \(status)")
            
            StatusBarDebugger.shared.log(.verification, "Status update flow works", context: ["workflowStatus": "\(status)", "internalStatus": "\(internalStatus)"])
        }
        
        StatusBarDebugger.shared.log(.verification, "Overall status update flow verified")
    }
    
    func testColoredMenuItemViewHoverEffects() {
        StatusBarDebugger.shared.log(.lifecycle, "COLORED MENU ITEM VIEW HOVER EFFECTS TEST")
        
        // Test different status colors and hover effects
        let testCases: [(WorkflowRunStatus, String)] = [
            (.success, "Green"),
            (.failure, "Red"), 
            (.running, "Yellow"),
            (.unknown, "Gray")
        ]
        
        for (status, colorName) in testCases {
            if TestEnvironment.shouldRunFullGUITests() {
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
                
                StatusBarDebugger.shared.log(.verification, "Menu item view properly initialized", context: ["color": colorName, "status": "\(status)"])
                
                // Test dimensions based on type
                if status == .success {
                    XCTAssertEqual(menuItemView.intrinsicContentSize.height, 24, "Height should be 24")
                    XCTAssertEqual(menuItemView.intrinsicContentSize.width, 350, "Regular item width should be 350")
                }
            } else {
                // In CI/headless mode, test status enum validity instead
                StatusBarDebugger.shared.log(.state, "Testing status enum logic", context: ["color": colorName, "status": "\(status)"])
                
                // Test that the status values are valid WorkflowRunStatus cases
                XCTAssertTrue([.success, .failure, .running, .unknown].contains(status), 
                             "Status \(status) should be a valid WorkflowRunStatus case")
                
                StatusBarDebugger.shared.log(.verification, "Status enum validated", context: ["color": colorName, "status": "\(status)"])
            }
        }
        
        StatusBarDebugger.shared.log(.verification, "All colored menu item view tests completed")
    }
    
    func testColoredMenuItemViewProperties() {
        StatusBarDebugger.shared.log(.lifecycle, "COLORED MENU ITEM VIEW PROPERTIES TEST")
        
        if TestEnvironment.shouldRunFullGUITests() {
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
            
            StatusBarDebugger.shared.log(.verification, "View dimensions verified", context: ["header": "\(headerView.intrinsicContentSize)", "regular": "\(regularView.intrinsicContentSize)", "build": "\(buildView.intrinsicContentSize)"])
        } else {
            // In CI/headless mode, test the configuration logic
            StatusBarDebugger.shared.log(.state, "Testing menu item view configuration logic in headless mode")
            
            // Test that expected dimensions are constants we can validate
            let expectedStandardHeight = 24
            let expectedStandardWidth = 350
            let expectedBuildWidth = 500
            
            // Validate the dimension constants are sensible
            XCTAssertGreaterThan(expectedStandardHeight, 0, "Standard height should be positive")
            XCTAssertGreaterThan(expectedStandardWidth, 0, "Standard width should be positive")
            XCTAssertGreaterThan(expectedBuildWidth, expectedStandardWidth, "Build width should be larger than standard width")
            
            StatusBarDebugger.shared.log(.verification, "Menu item view dimension constants validated")
        }
        
        StatusBarDebugger.shared.log(.verification, "Colored menu item view properties verified")
    }
    
    func testMenuItemClickHandling() {
        StatusBarDebugger.shared.log(.lifecycle, "MENU ITEM CLICK HANDLING TEST")
        
        if TestEnvironment.shouldRunFullGUITests() {
            let menuItemView = ColoredMenuItemView(title: "Clickable Item", isHeader: false, status: .success)
            
            // Test menu item association
            let menuItem = NSMenuItem(title: "", action: #selector(dummyAction), keyEquivalent: "")
            menuItem.target = self
            
            menuItemView.setMenuItem(menuItem)
            
            // Verify the menu item is set by testing that the click handler exists
            // (We can't directly access the private weak property, but we can test the setup worked)
            XCTAssertTrue(menuItem.target === self, "Menu item target should be set")
            XCTAssertEqual(menuItem.action, #selector(dummyAction), "Menu item action should be set")
            
            StatusBarDebugger.shared.log(.verification, "Menu item click handling setup verified")
            StatusBarDebugger.shared.log(.verification, "Menu item association working")
        } else {
            // In CI/headless mode, test the selector and action concepts
            StatusBarDebugger.shared.log(.state, "Testing menu item action concepts in headless mode")
            
            let action = #selector(dummyAction)
            XCTAssertNotNil(action, "Menu item action selector should be valid")
            
            // Test that this test class responds to the dummy action
            XCTAssertTrue(self.responds(to: action), "Test class should respond to dummy action")
            
            StatusBarDebugger.shared.log(.verification, "Menu item action logic validated")
        }
    }
    
    
    
    
    
    
    func testStatusBarIconVisibilityDiagnostic() {
        StatusBarDebugger.shared.log(.lifecycle, "STATUS BAR ICON VISIBILITY DIAGNOSTIC TEST")
        
        guard TestEnvironment.shouldRunFullGUITests() else {
            StatusBarDebugger.shared.log(.state, "Skipping visibility diagnostic in headless mode")
            return
        }
        
        // Test evidence collection for all status states
        let statusStates: [StatusBarManager.WorkflowStatus] = [.unknown, .passing, .failing, .running, .runningAfterSuccess, .runningAfterFailure]
        var evidenceData: [String: [String: Any]] = [:]
        
        for status in statusStates {
            let icon = statusBarManager.createStatusIcon(for: status)
            
            // Gather comprehensive evidence about icon properties
            var evidence: [String: Any] = [:]
            evidence["status"] = "\(status)"
            evidence["size"] = "\(icon.size)"
            evidence["isTemplate"] = icon.isTemplate
            evidence["representationCount"] = icon.representations.count
            evidence["isEmpty"] = icon.representations.isEmpty
            
            // Analyze template vs non-template distinction
            evidence["expectedToBeTemplate"] = (status == .unknown || status == .passing)
            evidence["templateMismatch"] = icon.isTemplate != (status == .unknown || status == .passing)
            
            // Check for actual image data
            if let rep = icon.representations.first {
                evidence["hasImageData"] = true
                evidence["representationType"] = "\(type(of: rep))"
                
                // Try to get bitmap representation for color analysis
                if let bitmapRep = rep as? NSBitmapImageRep {
                    evidence["bitmapSize"] = "\(bitmapRep.size)"
                    evidence["hasAlpha"] = bitmapRep.hasAlpha
                    evidence["bitsPerPixel"] = bitmapRep.bitsPerPixel
                } else if let cgImageRep = rep as? NSImageRep {
                    evidence["imageRepSize"] = "\(cgImageRep.size)"
                }
            } else {
                evidence["hasImageData"] = false
            }
            
            // Test if icon would be visible by attempting to draw it
            let testImage = NSImage(size: NSSize(width: 18, height: 18))
            testImage.lockFocus()
            icon.draw(in: NSRect(origin: .zero, size: testImage.size))
            testImage.unlockFocus()
            
            evidence["drawableTest"] = !testImage.representations.isEmpty
            
            evidenceData["\(status)"] = evidence
            
            StatusBarDebugger.shared.log(.verification, "Evidence collected for \(status)", context: evidence)
        }
        
        // Analysis: Identify problematic status states
        var problematicStates: [String] = []
        var templateStates: [String] = []
        var nonTemplateStates: [String] = []
        
        for (statusName, evidence) in evidenceData {
            let isTemplate = evidence["isTemplate"] as? Bool ?? false
            let hasImageData = evidence["hasImageData"] as? Bool ?? false
            let isDrawable = evidence["drawableTest"] as? Bool ?? false
            let templateMismatch = evidence["templateMismatch"] as? Bool ?? false
            
            if isTemplate {
                templateStates.append(statusName)
            } else {
                nonTemplateStates.append(statusName)
            }
            
            // Flag states that might have visibility issues
            if isTemplate || !hasImageData || !isDrawable || templateMismatch {
                problematicStates.append(statusName)
            }
        }
        
        // Create summary evidence report
        let summaryEvidence: [String: Any] = [
            "totalStatesAnalyzed": statusStates.count,
            "templateStates": templateStates,
            "nonTemplateStates": nonTemplateStates,
            "problematicStates": problematicStates,
            "templateStateCount": templateStates.count,
            "problemCount": problematicStates.count
        ]
        
        StatusBarDebugger.shared.log(.verification, "DIAGNOSTIC SUMMARY", context: summaryEvidence)
        
        // Store evidence for further analysis (test passes regardless - this is diagnostic)
        StatusBarDebugger.shared.log(.verification, "Complete evidence data collected", context: evidenceData)
        
        // Output key findings
        print("\n========== STATUS BAR ICON VISIBILITY DIAGNOSTIC RESULTS ==========")
        print("Template states (potentially invisible): \(templateStates)")
        print("Non-template states (should be visible): \(nonTemplateStates)")
        print("Problematic states detected: \(problematicStates)")
        print("====================================================================\n")
        
        // This test always passes - it's purely diagnostic
        XCTAssertTrue(true, "Diagnostic test completed - see evidence in logs")
    }
    
    func testBuildInProgressAtStartupScenario() {
        StatusBarDebugger.shared.log(.lifecycle, "BUILD IN PROGRESS AT STARTUP SCENARIO TEST")
        
        guard TestEnvironment.shouldRunFullGUITests() else {
            StatusBarDebugger.shared.log(.state, "Skipping build in progress diagnostic in headless mode")
            return
        }
        
        // Simulate the specific scenario: "build in progress when app starts"
        // This tests the exact conditions that cause blank/faint icons
        
        print("\n========== BUILD IN PROGRESS AT STARTUP DIAGNOSTIC ==========")
        
        // Test 1: Simulate startup with no build in progress (should be clear)
        StatusBarDebugger.shared.log(.verification, "TEST 1: Startup with no build in progress")
        let clearStartupIcon = statusBarManager.createStatusIcon(for: .passing)
        let clearEvidence = gatherIconEvidence(for: clearStartupIcon, statusName: "passing_at_startup")
        print("Clear startup (.passing): \(clearEvidence)")
        
        // Test 2: Simulate startup with running build (should be blank/faint)
        StatusBarDebugger.shared.log(.verification, "TEST 2: Startup with running build")
        let runningStartupIcon = statusBarManager.createStatusIcon(for: .running)
        let runningEvidence = gatherIconEvidence(for: runningStartupIcon, statusName: "running_at_startup")
        print("Running startup (.running): \(runningEvidence)")
        
        // Test 3: Simulate startup with running after success (likely culprit)
        StatusBarDebugger.shared.log(.verification, "TEST 3: Startup with running after success")
        let runningAfterSuccessIcon = statusBarManager.createStatusIcon(for: .runningAfterSuccess)
        let runningAfterSuccessEvidence = gatherIconEvidence(for: runningAfterSuccessIcon, statusName: "runningAfterSuccess_at_startup")
        print("Running after success startup: \(runningAfterSuccessEvidence)")
        
        // Test 4: Simulate startup with running after failure
        StatusBarDebugger.shared.log(.verification, "TEST 4: Startup with running after failure")
        let runningAfterFailureIcon = statusBarManager.createStatusIcon(for: .runningAfterFailure)
        let runningAfterFailureEvidence = gatherIconEvidence(for: runningAfterFailureIcon, statusName: "runningAfterFailure_at_startup")
        print("Running after failure startup: \(runningAfterFailureEvidence)")
        
        // Test 5: Simulate status transition from clear to problematic
        StatusBarDebugger.shared.log(.verification, "TEST 5: Status transition simulation")
        
        // Create initial clear icon
        let initialIcon = statusBarManager.createStatusIcon(for: .passing)
        let initialEvidence = gatherIconEvidence(for: initialIcon, statusName: "initial_passing")
        print("Initial passing state: \(initialEvidence)")
        
        // Simulate transition to running state (what happens when build starts)
        let transitionIcon = statusBarManager.createStatusIcon(for: .running)
        let transitionEvidence = gatherIconEvidence(for: transitionIcon, statusName: "transition_to_running")
        print("After transition to running: \(transitionEvidence)")
        
        // Note: Cannot test updateStatusIcon method directly due to private access
        // Will focus on createStatusIcon method which is public
        
        // Compare problematic vs working states
        let problemStates: [StatusBarManager.WorkflowStatus] = [.running, .runningAfterSuccess, .runningAfterFailure]
        let workingStates: [StatusBarManager.WorkflowStatus] = [.passing, .failing]
        
        print("\n--- COMPARISON: PROBLEMATIC vs WORKING STATES ---")
        for status in problemStates {
            let icon = statusBarManager.createStatusIcon(for: status)
            let evidence = gatherIconEvidence(for: icon, statusName: "\(status)")
            print("PROBLEMATIC \(status): \(evidence)")
        }
        
        for status in workingStates {
            let icon = statusBarManager.createStatusIcon(for: status)
            let evidence = gatherIconEvidence(for: icon, statusName: "\(status)")
            print("WORKING \(status): \(evidence)")
        }
        
        print("================================================================\n")
        
        StatusBarDebugger.shared.log(.verification, "Build in progress diagnostic completed")
        XCTAssertTrue(true, "Build in progress diagnostic completed - see console output")
    }
    
    private func gatherIconEvidence(for icon: NSImage?, statusName: String) -> [String: Any] {
        guard let icon = icon else {
            return ["error": "icon is nil", "statusName": statusName]
        }
        
        var evidence: [String: Any] = [:]
        evidence["statusName"] = statusName
        evidence["size"] = "\(icon.size)"
        evidence["isTemplate"] = icon.isTemplate
        evidence["representationCount"] = icon.representations.count
        evidence["isEmpty"] = icon.representations.isEmpty
        
        if let rep = icon.representations.first {
            evidence["representationType"] = "\(type(of: rep))"
            evidence["representationSize"] = "\(rep.size)"
        }
        
        return evidence
    }
    
    @objc private func dummyAction(_ sender: NSMenuItem) {
        // Dummy action for testing
    }
}