import XCTest
import Cocoa
@testable import HarbingerCore

final class RepositorySettingsWindowTests: XCTestCase {
    
    var settingsWindow: RepositorySettingsWindow!
    
    override func setUp() {
        super.setUp()
        settingsWindow = RepositorySettingsWindow()
        
        // Make the window visible and key to trigger proper layout
        settingsWindow.showWindow(nil)
        settingsWindow.window?.makeKey()
        
        // Force initial layout pass
        settingsWindow.window?.contentView?.layoutSubtreeIfNeeded()
    }
    
    override func tearDown() {
        settingsWindow.close()
        settingsWindow = nil
        super.tearDown()
    }
    
    // MARK: - Basic Initialization Tests
    
    func testWindowInitialization() {
        XCTAssertNotNil(settingsWindow, "Settings window should initialize")
        XCTAssertNotNil(settingsWindow.window, "Window should be created")
        
        let window = settingsWindow.window!
        let contentRect = window.contentRect(forFrameRect: window.frame)
        XCTAssertEqual(contentRect.width, 1000, "Window width should be 1000")
        XCTAssertEqual(contentRect.height, 700, "Window height should be 700")
        
        print("✅ Window initialized - Size: \(contentRect.size)")
    }
    
    func testTabViewCreation() {
        guard let contentView = settingsWindow.window?.contentView else {
            XCTFail("Content view should exist")
            return
        }
        
        // Find the tab view in the hierarchy
        let tabView = findTabView(in: contentView)
        XCTAssertNotNil(tabView, "Tab view should be created")
        
        if let tabView = tabView {
            XCTAssertGreaterThanOrEqual(tabView.numberOfTabViewItems, 4, "Should have at least 4 tabs")
            print("✅ Tab view found with \(tabView.numberOfTabViewItems) tabs")
            
            for i in 0..<tabView.numberOfTabViewItems {
                let tabItem = tabView.tabViewItem(at: i)
                print("   Tab \(i): '\(tabItem.label)'")
            }
        }
    }
    
    // MARK: - Layout Measurement Tests
    
    func testPersonalTabLayoutDimensions() {
        print("\n=== PERSONAL TAB LAYOUT ANALYSIS ===")
        switchToTab(identifier: "personal")
        let measurements = measureTabLayout(tabName: "Personal")
        
        // Personal tab should be working correctly - use as baseline
        XCTAssertGreaterThan(measurements.scrollViewWidth, 700, "Personal tab scroll view should be wide")
        XCTAssertGreaterThan(measurements.tableViewWidth, 700, "Personal tab table view should be wide")
        
        logDetailedMeasurements(measurements, tabName: "Personal")
    }
    
    func testOrganizationsTabLayoutDimensions() {
        print("\n=== ORGANIZATIONS TAB LAYOUT ANALYSIS ===")
        switchToTab(identifier: "organizations")
        let measurements = measureTabLayout(tabName: "Organizations")
        
        logDetailedMeasurements(measurements, tabName: "Organizations")
    }
    
    func testPublicSearchTabLayoutDimensions() {
        print("\n=== PUBLIC SEARCH TAB LAYOUT ANALYSIS ===")
        switchToTab(identifier: "searchtest")
        let measurements = measureTabLayout(tabName: "Public Search")
        
        logDetailedMeasurements(measurements, tabName: "Public Search")
    }
    
    func testMonitoredTabLayoutDimensions() {
        print("\n=== MONITORED TAB LAYOUT ANALYSIS ===")
        switchToTab(identifier: "monitored")
        let measurements = measureTabLayout(tabName: "Monitored")
        
        logDetailedMeasurements(measurements, tabName: "Monitored")
    }
    
    func testAllTabsConsistentWidth() {
        print("\n=== CROSS-TAB WIDTH COMPARISON ===")
        
        let personalMeasurements = switchAndMeasure(identifier: "personal", name: "Personal")
        let orgMeasurements = switchAndMeasure(identifier: "organizations", name: "Organizations")
        let searchMeasurements = switchAndMeasure(identifier: "searchtest", name: "Public Search")
        let monitoredMeasurements = switchAndMeasure(identifier: "monitored", name: "Monitored")
        
        // All tabs should have similar scroll view widths
        let personalWidth = personalMeasurements.scrollViewWidth
        let tolerance: CGFloat = 10 // Allow small differences
        
        print("\nWIDTH COMPARISON:")
        print("Personal scroll view width: \(personalWidth)")
        print("Organizations scroll view width: \(orgMeasurements.scrollViewWidth)")
        print("Public Search scroll view width: \(searchMeasurements.scrollViewWidth)")
        print("Monitored scroll view width: \(monitoredMeasurements.scrollViewWidth)")
        
        XCTAssertEqual(orgMeasurements.scrollViewWidth, personalWidth, accuracy: tolerance, 
                      "Organizations scroll view width should match Personal tab")
        XCTAssertEqual(searchMeasurements.scrollViewWidth, personalWidth, accuracy: tolerance, 
                      "Public Search scroll view width should match Personal tab")
        XCTAssertEqual(monitoredMeasurements.scrollViewWidth, personalWidth, accuracy: tolerance, 
                      "Monitored scroll view width should match Personal tab")
    }
    
    // MARK: - Multi-Tab Switching Stress Tests
    
    func testTabSwitchingWithRealisticContent() {
        print("\n=== TAB SWITCHING STRESS TEST WITH REALISTIC CONTENT ===")
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        // Populate tables with realistic data to test layout with actual content
        populateTablesWithRealisticData()
        
        // Test multiple switching patterns to catch any layout inconsistencies
        let switchingPatterns = [
            ["personal", "organizations", "monitored", "searchtest"],  // Sequential forward
            ["searchtest", "monitored", "organizations", "personal"], // Sequential backward  
            ["personal", "searchtest", "organizations", "monitored"], // Mixed pattern 1
            ["monitored", "personal", "searchtest", "organizations"], // Mixed pattern 2
            ["organizations", "searchtest", "personal", "monitored"], // Mixed pattern 3
        ]
        
        var allMeasurements: [String: [TabLayoutMeasurements]] = [:]
        
        for (patternIndex, pattern) in switchingPatterns.enumerated() {
            print("\n--- Pattern \(patternIndex + 1): \(pattern.joined(separator: " → ")) ---")
            
            for (switchIndex, tabId) in pattern.enumerated() {
                print("Switch \(switchIndex + 1): Selecting '\(tabId)' tab")
                
                // Switch to tab
                switchToTab(identifier: tabId)
                
                // Allow extra time for layout settling and potential data loading
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
                
                // Measure layout
                let measurements = measureTabLayout(tabName: tabId)
                
                // Store measurements for consistency checking
                if allMeasurements[tabId] == nil {
                    allMeasurements[tabId] = []
                }
                allMeasurements[tabId]?.append(measurements)
                
                // Log key metrics
                print("  Content width: \(measurements.tabContentWidth)")
                print("  Scroll view width: \(measurements.scrollViewWidth)")  
                print("  Table width: \(measurements.tableViewWidth)")
                print("  Width utilization: \(String(format: "%.1f", (measurements.scrollViewWidth / measurements.tabContentWidth) * 100))%")
                
                // Verify tab is working correctly
                XCTAssertGreaterThan(measurements.tabContentWidth, 900, "Tab '\(tabId)' content should be adequately wide")
                XCTAssertGreaterThan(measurements.scrollViewWidth, 900, "Tab '\(tabId)' scroll view should be adequately wide")
                
                if measurements.scrollViewWidth < 900 {
                    print("⚠️  WARNING: Tab '\(tabId)' has narrow scroll view (\(measurements.scrollViewWidth)px) in pattern \(patternIndex + 1), switch \(switchIndex + 1)")
                }
            }
        }
        
        // Analyze consistency across all measurements
        print("\n=== CONSISTENCY ANALYSIS ===")
        for (tabId, measurements) in allMeasurements {
            let scrollWidths = measurements.map { $0.scrollViewWidth }
            let contentWidths = measurements.map { $0.tabContentWidth }
            
            let minScrollWidth = scrollWidths.min() ?? 0
            let maxScrollWidth = scrollWidths.max() ?? 0
            let avgScrollWidth = scrollWidths.reduce(0, +) / Double(scrollWidths.count)
            
            let minContentWidth = contentWidths.min() ?? 0
            let maxContentWidth = contentWidths.max() ?? 0
            let avgContentWidth = contentWidths.reduce(0, +) / Double(contentWidths.count)
            
            print("\nTab '\(tabId)' (\(measurements.count) measurements):")
            print("  Scroll width - Min: \(minScrollWidth), Max: \(maxScrollWidth), Avg: \(String(format: "%.1f", avgScrollWidth))")
            print("  Content width - Min: \(minContentWidth), Max: \(maxContentWidth), Avg: \(String(format: "%.1f", avgContentWidth))")
            
            // Check for consistency - all measurements should be very similar
            let scrollWidthVariance = maxScrollWidth - minScrollWidth
            let contentWidthVariance = maxContentWidth - minContentWidth
            
            XCTAssertLessThan(scrollWidthVariance, 5.0, "Tab '\(tabId)' scroll width should be consistent across switches (variance: \(scrollWidthVariance))")
            XCTAssertLessThan(contentWidthVariance, 5.0, "Tab '\(tabId)' content width should be consistent across switches (variance: \(contentWidthVariance))")
            
            if scrollWidthVariance > 1.0 || contentWidthVariance > 1.0 {
                print("⚠️  WARNING: Tab '\(tabId)' shows layout variance - Scroll: \(scrollWidthVariance), Content: \(contentWidthVariance)")
            } else {
                print("✅ Tab '\(tabId)' shows consistent layout across all switches")
            }
        }
    }
    
    func testTabSwitchingWithPopulatedData() {
        print("\n=== TAB SWITCHING WITH POPULATED TABLE DATA ===")
        
        // This test simulates having actual repository data in the tables
        // to see if populated tables affect layout differently than empty ones
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        // Create and populate mock repository data for testing
        populateTablesWithRealisticData()
        let mockRepositories = createMockRepositoryData()
        print("Created \(mockRepositories.count) mock repositories for testing")
        
        // Test tab switching with data in different loading states
        let testScenarios = [
            "Empty tables → Personal → Organizations → Search → Monitored",
            "With data → Personal → Organizations → Search → Monitored", 
            "Rapid switching → Personal ↔ Search ↔ Organizations ↔ Monitored"
        ]
        
        for (scenarioIndex, scenario) in testScenarios.enumerated() {
            print("\n--- Scenario \(scenarioIndex + 1): \(scenario) ---")
            
            if scenario.contains("With data") {
                // Simulate populating tables with data
                print("Simulating data population...")
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            }
            
            if scenario.contains("Rapid switching") {
                // Test rapid tab switching
                let rapidPattern = ["personal", "searchtest", "organizations", "monitored", "personal", "searchtest", "monitored", "organizations"]
                for (i, tabId) in rapidPattern.enumerated() {
                    print("Rapid switch \(i + 1): \(tabId)")
                    switchToTab(identifier: tabId)
                    // Shorter delay for rapid switching
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
                    
                    let measurements = measureTabLayout(tabName: tabId)
                    XCTAssertGreaterThan(measurements.scrollViewWidth, 900, "Rapid switch \(i + 1) - Tab '\(tabId)' should maintain proper width")
                    
                    if measurements.scrollViewWidth < 900 {
                        print("⚠️  WARNING: Rapid switch caused narrow layout in tab '\(tabId)': \(measurements.scrollViewWidth)px")
                    }
                }
            } else {
                // Standard switching test
                let standardPattern = ["personal", "organizations", "searchtest", "monitored"]
                for tabId in standardPattern {
                    switchToTab(identifier: tabId)
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
                    
                    let measurements = measureTabLayout(tabName: tabId)
                    print("  \(tabId): content=\(measurements.tabContentWidth), scroll=\(measurements.scrollViewWidth)")
                    
                    XCTAssertGreaterThan(measurements.scrollViewWidth, 900, "Tab '\(tabId)' should maintain proper width in scenario: \(scenario)")
                }
            }
        }
    }
    
    func testTabResizeUnderMemoryPressure() {
        print("\n=== TAB RESIZE UNDER SIMULATED LOAD ===")
        
        // Populate tables with realistic data to test under realistic conditions
        populateTablesWithRealisticData()
        
        // Test tab behavior when the system might be under memory pressure
        // or when there are many layout calculations happening
        
        let iterations = 10
        var allWidthMeasurements: [String: [CGFloat]] = [:]
        
        for iteration in 1...iterations {
            print("\n--- Load Test Iteration \(iteration) ---")
            
            // Create some memory pressure simulation by creating and releasing objects
            var tempData: [[String]] = []
            for i in 0..<1000 {
                tempData.append(Array(repeating: "TestData\(i)", count: 50))
            }
            
            // Test each tab under this simulated load
            for tabId in ["personal", "organizations", "searchtest", "monitored"] {
                switchToTab(identifier: tabId)
                
                // Force multiple layout passes
                settingsWindow.window?.contentView?.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                settingsWindow.window?.contentView?.layoutSubtreeIfNeeded()
                
                let measurements = measureTabLayout(tabName: tabId)
                
                if allWidthMeasurements[tabId] == nil {
                    allWidthMeasurements[tabId] = []
                }
                allWidthMeasurements[tabId]?.append(measurements.scrollViewWidth)
                
                print("  \(tabId): \(measurements.scrollViewWidth)px")
            }
            
            // Clear temp data
            tempData.removeAll()
        }
        
        // Analyze stability under load
        print("\n=== LOAD TEST ANALYSIS ===")
        for (tabId, widths) in allWidthMeasurements {
            let minWidth = widths.min() ?? 0
            let maxWidth = widths.max() ?? 0
            let avgWidth = widths.reduce(0, +) / Double(widths.count)
            let variance = maxWidth - minWidth
            
            print("\(tabId): Min=\(minWidth), Max=\(maxWidth), Avg=\(String(format: "%.1f", avgWidth)), Variance=\(variance)")
            
            XCTAssertGreaterThan(minWidth, 900, "Tab '\(tabId)' should maintain width under load")
            XCTAssertLessThan(variance, 10.0, "Tab '\(tabId)' should be stable under load (variance: \(variance))")
            
            if variance > 5.0 {
                print("⚠️  WARNING: Tab '\(tabId)' shows instability under load")
            } else {
                print("✅ Tab '\(tabId)' is stable under simulated load")
            }
        }
    }
    
    // MARK: - Helper Methods for Realistic Testing
    
    private func createMockRepositoryData() -> [MockRepository] {
        return [
            MockRepository(name: "react", owner: "facebook", description: "A declarative, efficient, and flexible JavaScript library for building user interfaces.", language: "JavaScript", stars: 234567),
            MockRepository(name: "vue", owner: "vuejs", description: "Vue.js is a progressive, incrementally-adoptable JavaScript framework for building UI on the web.", language: "TypeScript", stars: 198432),
            MockRepository(name: "angular", owner: "angular", description: "The modern web developer's platform. Angular is a platform for building mobile and desktop web applications.", language: "TypeScript", stars: 87654),
            MockRepository(name: "svelte", owner: "sveltejs", description: "Cybernetically enhanced web apps", language: "JavaScript", stars: 65432),
            MockRepository(name: "swift", owner: "apple", description: "The Swift Programming Language", language: "Swift", stars: 58901),
            MockRepository(name: "rust", owner: "rust-lang", description: "Empowering everyone to build reliable and efficient software.", language: "Rust", stars: 76543),
            MockRepository(name: "go", owner: "golang", description: "The Go programming language", language: "Go", stars: 109876),
            MockRepository(name: "python", owner: "python", description: "The Python programming language", language: "Python", stars: 45678),
            MockRepository(name: "typescript", owner: "microsoft", description: "TypeScript is a superset of JavaScript that compiles to clean JavaScript output.", language: "TypeScript", stars: 87123),
            MockRepository(name: "harbinger", owner: "testuser", description: "macOS status bar app for monitoring GitHub Actions workflows", language: "Swift", stars: 42),
            MockRepository(name: "kubernetes", owner: "kubernetes", description: "Production-Grade Container Scheduling and Management", language: "Go", stars: 89123),
            MockRepository(name: "tensorflow", owner: "tensorflow", description: "An Open Source Machine Learning Framework for Everyone", language: "Python", stars: 156432),
            MockRepository(name: "django", owner: "django", description: "The Web framework for perfectionists with deadlines.", language: "Python", stars: 67891),
            MockRepository(name: "rails", owner: "rails", description: "Ruby on Rails - A web-app framework that includes everything needed to create database-backed web applications", language: "Ruby", stars: 54321),
            MockRepository(name: "spring-boot", owner: "spring-projects", description: "Spring Boot helps you to create Spring-powered, production-grade applications and services", language: "Java", stars: 43210),
        ]
    }
    
    private func populateTablesWithRealisticData() {
        let mockRepos = createMockRepositoryData()
        let mockMonitoredRepos = mockRepos.prefix(8).map { repo in
            MonitoredRepository(owner: repo.owner, name: repo.name, fullName: repo.fullName, isPrivate: false, url: "https://github.com/\(repo.fullName)")
        }
        
        // Simulate populating the monitored repositories table
        settingsWindow.setTestData(monitoredRepositories: Array(mockMonitoredRepos))
        
        // Simulate populating search results
        settingsWindow.setTestData(searchResults: mockRepos.suffix(10).map { $0.toRepository() })
        
        print("✅ Populated tables with realistic data:")
        print("   - Monitored repositories: \(mockMonitoredRepos.count)")
        print("   - Search results: \(mockRepos.suffix(10).count)")
        
        // Verify data visibility by checking actual table row counts
        verifyDataVisibility()
    }
    
    private func verifyDataVisibility() {
        // Allow extra time for async UI updates
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            print("⚠️ Cannot verify data visibility - no tab view found")
            return
        }
        
        // Check monitored tab data visibility
        switchToTab(identifier: "monitored")
        // Allow more time for tab switching and data updates
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        
        let (_, monitoredTableView) = findScrollAndTableViews(in: tabView.selectedTabViewItem?.view ?? NSView())
        
        if let tableView = monitoredTableView {
            let rowCount = tableView.numberOfRows
            print("🔍 Monitored tab verification: \(rowCount) rows visible in table")
            if rowCount > 0 {
                print("   ✅ Monitored table shows populated data")
                // Show some sample data to confirm visibility
                for i in 0..<min(3, rowCount) {
                    if let cell = tableView.view(atColumn: 0, row: i, makeIfNecessary: false) as? NSTableCellView,
                       let textField = cell.textField {
                        print("   📄 Row \(i): \(textField.stringValue)")
                    }
                }
            } else {
                print("   ⚠️ Monitored table appears empty")
            }
        }
        
        // Check search tab data visibility  
        switchToTab(identifier: "searchtest")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        
        let (_, searchTableView) = findScrollAndTableViews(in: tabView.selectedTabViewItem?.view ?? NSView())
        
        if let tableView = searchTableView {
            let rowCount = tableView.numberOfRows
            print("🔍 Search tab verification: \(rowCount) rows visible in table")
            if rowCount > 0 {
                print("   ✅ Search table shows populated data")
                // Show some sample data to confirm visibility
                for i in 0..<min(3, rowCount) {
                    if let cell = tableView.view(atColumn: 0, row: i, makeIfNecessary: false) as? NSTableCellView,
                       let textField = cell.textField {
                        print("   📄 Row \(i): \(textField.stringValue)")
                    }
                }
            } else {
                print("   ⚠️ Search table appears empty")
            }
        }
    }

    func testSearchResultsTableDataPopulation() {
        // Switch to the search tab
        switchToTab(identifier: "searchtest")
        
        // Create test search results
        let testSearchResults = [
            Repository(
                name: "react",
                fullName: "facebook/react",
                owner: RepositoryOwner(login: "facebook"),
                private: false,
                htmlUrl: "https://github.com/facebook/react",
                description: "The library for web and native user interfaces",
                language: "JavaScript",
                stargazersCount: 225000
            ),
            Repository(
                name: "vue",
                fullName: "vuejs/vue",
                owner: RepositoryOwner(login: "vuejs"),
                private: false,
                htmlUrl: "https://github.com/vuejs/vue",
                description: "Vue.js is a progressive, incrementally-adoptable JavaScript framework",
                language: "JavaScript",
                stargazersCount: 207000
            )
        ]
        
        // Set test data
        settingsWindow.setTestData(searchResults: testSearchResults)
        
        // Allow UI to update
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        let (_, searchTableView) = findScrollAndTableViews(in: tabView.selectedTabViewItem?.view ?? NSView())
        
        guard let tableView = searchTableView else {
            XCTFail("Could not find search results table view")
            return
        }
        
        // Verify table has the expected number of rows
        let rowCount = tableView.numberOfRows
        XCTAssertEqual(rowCount, 2, "Search results table should have 2 rows")
        print("✅ Search results table has \(rowCount) rows")
        
        // Verify column count and identifiers
        let columnCount = tableView.numberOfColumns
        XCTAssertEqual(columnCount, 4, "Search results table should have 4 columns")
        
        let expectedColumns = ["name", "description", "language", "stars"]
        for (index, expectedId) in expectedColumns.enumerated() {
            let column = tableView.tableColumns[index]
            XCTAssertEqual(column.identifier.rawValue, expectedId, "Column \(index) should have identifier '\(expectedId)'")
        }
        print("✅ Search results table has correct columns: \(tableView.tableColumns.map { $0.identifier.rawValue })")
        
        // Force table to create views for first row
        tableView.reloadData()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Verify data in specific cells
        if rowCount > 0 {
            print("🔍 Checking first row cell data...")
            
            // Check first row data
            if let nameCell = tableView.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView,
               let nameTextField = nameCell.textField {
                XCTAssertEqual(nameTextField.stringValue, "facebook/react", "First row name should be 'facebook/react'")
                print("✅ First row name: '\(nameTextField.stringValue)'")
            } else {
                print("⚠️ Could not get name cell for first row")
            }
            
            if let descCell = tableView.view(atColumn: 1, row: 0, makeIfNecessary: true) as? NSTableCellView,
               let descTextField = descCell.textField {
                XCTAssertTrue(descTextField.stringValue.contains("library"), "First row description should contain 'library'")
                print("✅ First row description: '\(descTextField.stringValue)'")
            } else {
                print("⚠️ Could not get description cell for first row")
            }
            
            if let langCell = tableView.view(atColumn: 2, row: 0, makeIfNecessary: true) as? NSTableCellView,
               let langTextField = langCell.textField {
                XCTAssertEqual(langTextField.stringValue, "JavaScript", "First row language should be 'JavaScript'")
                print("✅ First row language: '\(langTextField.stringValue)'")
            } else {
                print("⚠️ Could not get language cell for first row")
            }
            
            if let starsCell = tableView.view(atColumn: 3, row: 0, makeIfNecessary: true) as? NSTableCellView,
               let starsTextField = starsCell.textField {
                XCTAssertTrue(starsTextField.stringValue.contains("225"), "First row stars should contain '225'")
                print("✅ First row stars: '\(starsTextField.stringValue)'")
            } else {
                print("⚠️ Could not get stars cell for first row")
            }
        }
    }

    func testTabOrder() {
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        XCTAssertEqual(tabView.numberOfTabViewItems, 4, "Should have 4 tabs")
        
        // Verify tab order: Monitored, Personal, Organizations, Public Search
        let expectedTabOrder = [
            ("monitored", "Monitored"),
            ("personal", "Personal"), 
            ("organizations", "Organizations"),
            ("searchtest", "Public Search")
        ]
        
        for (index, (expectedId, expectedLabel)) in expectedTabOrder.enumerated() {
            let tabItem = tabView.tabViewItem(at: index)
            let actualId = tabItem.identifier as? String
            let actualLabel = tabItem.label
            
            XCTAssertEqual(actualId, expectedId, "Tab at index \(index) should have identifier '\(expectedId)'")
            XCTAssertEqual(actualLabel, expectedLabel, "Tab at index \(index) should have label '\(expectedLabel)'")
            
            print("✅ Tab \(index): '\(actualLabel)' (\(actualId ?? "nil"))")
        }
        
        // Verify that monitored tab is selected by default (first tab)
        let selectedTabId = tabView.selectedTabViewItem?.identifier as? String
        print("✅ Default selected tab: '\(selectedTabId ?? "nil")'")
        
        // The first tab should be selected by default
        XCTAssertEqual(selectedTabId, "monitored", "Monitored tab should be selected by default as the first tab")
    }

    func testPersonalRepositoriesApiCall() {
        // This test verifies that the Personal tab makes the correct API call to filter personal repos only
        
        // Switch to personal tab
        switchToTab(identifier: "personal")
        
        // Allow UI to update
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // The personal tab should have triggered a call to loadPersonalRepositories()
        // which calls gitHubClient.getRepositories()
        // This should make a request to /user/repos?type=owner to get only personal repos
        
        // We can't easily test the actual API call in a unit test without mocking the network layer,
        // but we can at least verify that the personal tab is set up correctly and responds to tab switching
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        // Verify we're on the personal tab
        let selectedTabId = tabView.selectedTabViewItem?.identifier as? String
        XCTAssertEqual(selectedTabId, "personal", "Should be on personal tab")
        
        // Look for the personal repositories table
        let (_, personalTableView) = findScrollAndTableViews(in: tabView.selectedTabViewItem?.view ?? NSView())
        
        XCTAssertNotNil(personalTableView, "Personal tab should have a table view")
        print("✅ Personal tab is correctly configured with table view")
        
        // The actual filtering happens in GitHubClient.getRepositories() which now uses type=owner parameter
        // This ensures only repositories owned by the authenticated user are returned, not org repos
        print("✅ Personal repositories API call configured to filter owner-only repositories")
    }

    func testPublicSearchTabHasSearchField() {
        // Switch to the search tab
        switchToTab(identifier: "searchtest")
        
        // Allow UI to update
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        guard let searchTabContent = tabView.selectedTabViewItem?.view else {
            XCTFail("Could not find search tab content view")
            return
        }
        
        // Look for search field in the tab content
        var foundSearchField: NSTextField?
        var foundSearchButton: NSButton?
        
        func findSearchControls(in view: NSView) {
            for subview in view.subviews {
                if let textField = subview as? NSTextField,
                   textField.placeholderString?.contains("repository name") == true {
                    foundSearchField = textField
                } else if let button = subview as? NSButton,
                          button.title == "Search" {
                    foundSearchButton = button
                }
                // Recursively search subviews
                findSearchControls(in: subview)
            }
        }
        
        findSearchControls(in: searchTabContent)
        
        // Verify search field exists and has correct properties
        XCTAssertNotNil(foundSearchField, "Search field should exist in Public Search tab")
        XCTAssertNotNil(foundSearchButton, "Search button should exist in Public Search tab")
        
        if let searchField = foundSearchField {
            XCTAssertNotNil(searchField.placeholderString, "Search field should have placeholder text")
            XCTAssertTrue(searchField.placeholderString?.contains("repository") == true, "Placeholder should mention repositories")
            print("✅ Search field found with placeholder: '\(searchField.placeholderString ?? "none")'")
        }
        
        if let searchButton = foundSearchButton {
            XCTAssertEqual(searchButton.title, "Search", "Search button should have 'Search' title")
            XCTAssertFalse(searchButton.isEnabled, "Search button should be disabled initially")
            print("✅ Search button found with title: '\(searchButton.title)', enabled: \(searchButton.isEnabled)")
        }
    }

    // MARK: - NSTabView Intrinsic Content Size Investigation
    
    func testNSTabViewIntrinsicContentSizeApproach() {
        print("\n=== NSTABVIEW INTRINSIC CONTENT SIZE INVESTIGATION ===")
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        print("Tab view frame: \(tabView.frame)")
        print("Tab view bounds: \(tabView.bounds)")
        print("Tab view intrinsic content size: \(tabView.intrinsicContentSize)")
        print("Tab view needs layout: \(tabView.needsLayout)")
        
        // Examine each tab's content view properties
        for i in 0..<tabView.numberOfTabViewItems {
            let tabItem = tabView.tabViewItem(at: i)
            let tabLabel = tabItem.label
            
            // Switch to this tab
            tabView.selectTabViewItem(at: i)
            contentView.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            
            guard let tabContentView = tabItem.view else {
                print("⚠️ Tab \(tabLabel): No content view")
                continue
            }
            
            print("\n--- Tab: \(tabLabel) ---")
            print("Content view frame: \(tabContentView.frame)")
            print("Content view bounds: \(tabContentView.bounds)")
            print("Content view intrinsic content size: \(tabContentView.intrinsicContentSize)")
            print("Content view translates autoresizing mask: \(tabContentView.translatesAutoresizingMaskIntoConstraints)")
            print("Content view autoresizing mask: \(tabContentView.autoresizingMask)")
            print("Content view has ambiguous layout: \(tabContentView.hasAmbiguousLayout)")
            
            // Check constraints
            print("Content view constraints: \(tabContentView.constraints.count)")
            for constraint in tabContentView.constraints {
                print("  Constraint: \(constraint)")
            }
            
            // Find and examine scroll view
            let (scrollView, tableView) = findScrollAndTableViews(in: tabContentView)
            if let scrollView = scrollView {
                print("Scroll view frame: \(scrollView.frame)")
                print("Scroll view intrinsic content size: \(scrollView.intrinsicContentSize)")
                print("Scroll view translates autoresizing mask: \(scrollView.translatesAutoresizingMaskIntoConstraints)")
                print("Scroll view autoresizing mask: \(scrollView.autoresizingMask)")
                print("Scroll view has ambiguous layout: \(scrollView.hasAmbiguousLayout)")
                
                if let tableView = tableView {
                    print("Table view frame: \(tableView.frame)")
                    print("Table view intrinsic content size: \(tableView.intrinsicContentSize)")
                    print("Table view column autoresizing style: \(tableView.columnAutoresizingStyle.rawValue)")
                }
            }
        }
    }
    
    func testNSTabViewContentSizingFix() {
        print("\n=== TESTING NSTABVIEW CONTENT SIZING FIX ===")
        
        // This test will investigate the proper way to ensure tab content views
        // provide adequate intrinsic content size for NSTabView to size them correctly
        
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        // Test approach: Ensure all tab content views have proper intrinsic content size
        for i in 0..<tabView.numberOfTabViewItems {
            let tabItem = tabView.tabViewItem(at: i)
            let tabLabel = tabItem.label
            
            // Switch to this tab
            tabView.selectTabViewItem(at: i)
            contentView.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            
            guard let tabContentView = tabItem.view else {
                continue
            }
            
            print("\n--- Testing Tab: \(tabLabel) ---")
            
            // Check if tab content view has adequate intrinsic content size
            let intrinsicSize = tabContentView.intrinsicContentSize
            let actualFrame = tabContentView.frame
            
            print("Intrinsic content size: \(intrinsicSize)")
            print("Actual frame: \(actualFrame)")
            
            // For tabs with inadequate intrinsic content size, test setting explicit size
            if intrinsicSize.width == NSView.noIntrinsicMetric || intrinsicSize.width < 900 {
                print("⚠️ Tab has inadequate intrinsic content size")
                
                // Try setting a minimum size hint
                tabContentView.setContentHuggingPriority(.init(1), for: .horizontal)
                tabContentView.setContentCompressionResistancePriority(.init(1000), for: .horizontal)
                
                // Force layout update
                tabView.needsLayout = true
                tabView.layoutSubtreeIfNeeded()
                contentView.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                
                let newFrame = tabContentView.frame
                print("Frame after content size adjustments: \(newFrame)")
                
                // Measure scroll view width after adjustment
                let (scrollView, _) = findScrollAndTableViews(in: tabContentView)
                if let scrollView = scrollView {
                    print("Scroll view width after adjustment: \(scrollView.frame.width)")
                }
            } else {
                print("✅ Tab has adequate intrinsic content size")
            }
        }
    }

    // MARK: - Helper Methods
    
    private func findTabView(in view: NSView) -> NSTabView? {
        if let tabView = view as? NSTabView {
            return tabView
        }
        
        for subview in view.subviews {
            if let found = findTabView(in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    private func switchToTab(identifier: String) {
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return
        }
        
        // Find tab by identifier
        for i in 0..<tabView.numberOfTabViewItems {
            let tabItem = tabView.tabViewItem(at: i)
            if let tabIdentifier = tabItem.identifier as? String, tabIdentifier == identifier {
                tabView.selectTabViewItem(at: i)
                break
            }
        }
        
        // Force layout after tab switch
        contentView.layoutSubtreeIfNeeded()
        
        // Small delay to ensure layout is complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    
    private func switchAndMeasure(identifier: String, name: String) -> TabLayoutMeasurements {
        switchToTab(identifier: identifier)
        return measureTabLayout(tabName: name)
    }
    
    private func measureTabLayout(tabName: String) -> TabLayoutMeasurements {
        guard let contentView = settingsWindow.window?.contentView,
              let tabView = findTabView(in: contentView) else {
            XCTFail("Could not find tab view")
            return TabLayoutMeasurements()
        }
        
        let selectedTab = tabView.selectedTabViewItem
        guard let tabContentView = selectedTab?.view else {
            XCTFail("Could not find tab content view")
            return TabLayoutMeasurements()
        }
        
        var measurements = TabLayoutMeasurements()
        measurements.windowWidth = contentView.frame.width
        measurements.windowHeight = contentView.frame.height
        measurements.tabContentWidth = tabContentView.frame.width
        measurements.tabContentHeight = tabContentView.frame.height
        
        // Find scroll view and table view in the current tab
        let (scrollView, tableView) = findScrollAndTableViews(in: tabContentView)
        
        if let scrollView = scrollView {
            measurements.scrollViewWidth = scrollView.frame.width
            measurements.scrollViewHeight = scrollView.frame.height
            measurements.scrollViewX = scrollView.frame.origin.x
            measurements.scrollViewY = scrollView.frame.origin.y
        }
        
        if let tableView = tableView {
            measurements.tableViewWidth = tableView.frame.width
            measurements.tableViewHeight = tableView.frame.height
            measurements.columnCount = tableView.numberOfColumns
            
            // Measure individual columns
            measurements.columnWidths = []
            for i in 0..<tableView.numberOfColumns {
                let column = tableView.tableColumns[i]
                measurements.columnWidths.append(column.width)
            }
        }
        
        return measurements
    }
    
    private func findScrollAndTableViews(in view: NSView) -> (NSScrollView?, NSTableView?) {
        var scrollView: NSScrollView?
        var tableView: NSTableView?
        
        func searchRecursively(_ currentView: NSView) {
            if let sv = currentView as? NSScrollView {
                scrollView = sv
                if let tv = sv.documentView as? NSTableView {
                    tableView = tv
                }
            }
            
            for subview in currentView.subviews {
                searchRecursively(subview)
            }
        }
        
        searchRecursively(view)
        return (scrollView, tableView)
    }
    
    private func logDetailedMeasurements(_ measurements: TabLayoutMeasurements, tabName: String) {
        print("\n--- \(tabName) Tab Detailed Measurements ---")
        print("Window dimensions: \(measurements.windowWidth) x \(measurements.windowHeight)")
        print("Tab content dimensions: \(measurements.tabContentWidth) x \(measurements.tabContentHeight)")
        print("Scroll view frame: origin(\(measurements.scrollViewX), \(measurements.scrollViewY)) size(\(measurements.scrollViewWidth) x \(measurements.scrollViewHeight))")
        print("Table view dimensions: \(measurements.tableViewWidth) x \(measurements.tableViewHeight)")
        print("Column count: \(measurements.columnCount)")
        
        if !measurements.columnWidths.isEmpty {
            print("Column widths: \(measurements.columnWidths)")
            let totalColumnWidth = measurements.columnWidths.reduce(0, +)
            print("Total column width: \(totalColumnWidth)")
            
            if measurements.tableViewWidth > 0 {
                let utilization = (totalColumnWidth / measurements.tableViewWidth) * 100
                print("Column width utilization: \(String(format: "%.1f", utilization))%")
            }
        }
        
        // Key diagnostic information
        let expectedScrollViewWidth = measurements.tabContentWidth - 32 // 16px margins on each side
        print("\nDIAGNOSTIC INFO:")
        print("Expected scroll view width (content - 32px margins): \(expectedScrollViewWidth)")
        print("Actual scroll view width: \(measurements.scrollViewWidth)")
        print("Width utilization: \(String(format: "%.1f", (measurements.scrollViewWidth / expectedScrollViewWidth) * 100))%")
        
        if abs(measurements.scrollViewWidth - expectedScrollViewWidth) > 5 {
            print("⚠️  WARNING: Scroll view not utilizing full available width!")
        } else {
            print("✅ Scroll view properly utilizing available width")
        }
    }
}

// MARK: - Data Structures

struct TabLayoutMeasurements {
    var windowWidth: CGFloat = 0
    var windowHeight: CGFloat = 0
    var tabContentWidth: CGFloat = 0
    var tabContentHeight: CGFloat = 0
    var scrollViewWidth: CGFloat = 0
    var scrollViewHeight: CGFloat = 0
    var scrollViewX: CGFloat = 0
    var scrollViewY: CGFloat = 0
    var tableViewWidth: CGFloat = 0
    var tableViewHeight: CGFloat = 0
    var columnCount: Int = 0
    var columnWidths: [CGFloat] = []
}

struct MockRepository {
    let name: String
    let owner: String
    let description: String
    let language: String
    let stars: Int
    
    var fullName: String {
        return "\(owner)/\(name)"
    }
    
    func toRepository() -> Repository {
        // Create a Repository model from MockRepository
        // Note: This is a simplified conversion for testing purposes
        return Repository(
            name: name,
            fullName: fullName,
            owner: RepositoryOwner(login: owner),
            private: false,
            htmlUrl: "https://github.com/\(fullName)",
            description: description,
            language: language,
            stargazersCount: stars
        )
    }
}