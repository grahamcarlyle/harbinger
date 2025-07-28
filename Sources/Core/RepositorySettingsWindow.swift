import Cocoa

public class RepositorySettingsWindow: NSWindowController {
    
    private let repositoryManager = RepositoryManager()
    private let gitHubClient: GitHubClientProtocol
    private var monitoredRepositories: [MonitoredRepository] = []
    
    
    // Main UI Elements
    private var tabView: NSTabView!
    private var refreshButton: NSButton!
    private var clearCacheButton: NSButton!
    private var closeButton: NSButton!
    private var loadingIndicator: NSProgressIndicator!
    
    // Personal Repositories Tab
    private var personalRepositories: [Repository] = []
    private var personalTableView: NSTableView!
    private var personalFilterField: NSTextField!
    private var personalSortButton: NSPopUpButton!
    
    // Organizations Tab
    private var userOrganizations: [Organization] = []
    private var selectedOrgRepositories: [Repository] = []
    private var organizationsPopUp: NSPopUpButton!
    private var orgTableView: NSTableView!
    private var orgFilterField: NSTextField!
    
    // Public Search Tab
    private var searchField: NSTextField!
    private var searchResultsTable: NSTableView!
    private var searchButton: NSButton!
    private var searchResults: [Repository] = []
    private var isSearching = false
    
    // Monitored Repositories Tab
    private var monitoredTableView: NSTableView!
    private var workflowTableView: NSTableView!
    private var workflowTableLabel: NSTextField!
    private var selectedRepository: MonitoredRepository?
    private var currentWorkflows: [Workflow] = []
    
    // Common elements across tabs
    private var tabAddButtons: [NSButton] = []
    private var monitoredRemoveButton: NSButton!
    
    public init(gitHubClient: GitHubClientProtocol = GitHubClient()) {
        self.gitHubClient = gitHubClient
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.minSize = NSSize(width: 800, height: 700)
        
        super.init(window: window)
        
        window.title = "Repository Settings"
        window.center()
        setupUI()
        loadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView()
        window.contentView = contentView
        
        // Create main stack view
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "GitHub Repository Monitor")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.alignment = .center
        mainStack.addArrangedSubview(titleLabel)
        
        // Create tabbed interface
        tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        tabView.delegate = self
        mainStack.addArrangedSubview(tabView)
        
        // Setup all tabs - Monitored first as it's most relevant and loads fastest
        setupMonitoredRepositoriesTab()
        setupPersonalRepositoriesTab()
        setupOrganizationsTab()
        setupPublicSearchTab()
        
        // Bottom buttons
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        
        refreshButton = NSButton(title: "Refresh Current Tab", target: self, action: #selector(refreshCurrentTab))
        clearCacheButton = NSButton(title: "Clear Cache", target: self, action: #selector(clearAllCaches))
        closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        
        buttonStack.addArrangedSubview(NSView()) // Spacer
        buttonStack.addArrangedSubview(refreshButton)
        buttonStack.addArrangedSubview(clearCacheButton)
        buttonStack.addArrangedSubview(closeButton)
        
        mainStack.addArrangedSubview(buttonStack)
        
        // Loading indicator
        loadingIndicator = NSProgressIndicator()
        loadingIndicator.style = .spinning
        loadingIndicator.isHidden = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        // Setup table view delegates
        personalTableView.delegate = self
        personalTableView.dataSource = self
        orgTableView.delegate = self
        orgTableView.dataSource = self
        searchResultsTable.delegate = self
        searchResultsTable.dataSource = self
        monitoredTableView.delegate = self
        monitoredTableView.dataSource = self
        workflowTableView.delegate = self
        workflowTableView.dataSource = self
    }
    
    // MARK: - Tab Setup Methods
    
    private func setupPersonalRepositoriesTab() {
        let tabItem = NSTabViewItem(identifier: "personal")
        tabItem.label = "Personal"
        
        let tabContent = NSView()
        // Ensure tab content view expands to fill available tab space
        tabContent.frame = NSRect(x: 0, y: 0, width: 1000, height: 600)
        tabContent.autoresizingMask = [.width, .height]
        // Ensure autoresizing mask is used instead of constraints
        tabContent.translatesAutoresizingMaskIntoConstraints = true
        
        // Filter and sort controls
        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 12
        
        // Filter field
        personalFilterField = NSTextField()
        personalFilterField.placeholderString = "Filter repositories..."
        personalFilterField.delegate = self
        personalFilterField.target = self
        personalFilterField.action = #selector(personalFilterChanged)
        
        // Sort dropdown
        personalSortButton = NSPopUpButton()
        personalSortButton.addItems(withTitles: ["Name (A-Z)", "Name (Z-A)", "Updated (Recent)", "Updated (Oldest)", "Stars (Most)", "Stars (Least)"])
        personalSortButton.target = self
        personalSortButton.action = #selector(personalSortChanged)
        personalSortButton.widthAnchor.constraint(equalToConstant: 150).isActive = true
        
        controlsStack.addArrangedSubview(personalFilterField)
        controlsStack.addArrangedSubview(personalSortButton)
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(controlsStack)
        
        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            controlsStack.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16)
        ])
        
        // Repository table
        personalTableView = NSTableView()
        personalTableView.rowSizeStyle = .default
        personalTableView.selectionHighlightStyle = .regular
        personalTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        personalTableView.usesAlternatingRowBackgroundColors = true
        personalTableView.allowsColumnReordering = false
        personalTableView.allowsColumnResizing = true
        
        // Add columns with better width distribution
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Repository"
        nameColumn.width = 250
        nameColumn.minWidth = 150
        nameColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(nameColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Description"
        descriptionColumn.width = 250
        descriptionColumn.minWidth = 150
        descriptionColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(descriptionColumn)
        
        let visibilityColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("visibility"))
        visibilityColumn.title = "Visibility"
        visibilityColumn.width = 80
        visibilityColumn.minWidth = 60
        visibilityColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(visibilityColumn)
        
        let workflowsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflows"))
        workflowsColumn.title = "Workflows"
        workflowsColumn.width = 80
        workflowsColumn.minWidth = 60
        workflowsColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(workflowsColumn)
        
        let languageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("language"))
        languageColumn.title = "Language"
        languageColumn.width = 120
        languageColumn.minWidth = 80
        languageColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(languageColumn)
        
        let updatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("updated"))
        updatedColumn.title = "Updated"
        updatedColumn.width = 150
        updatedColumn.minWidth = 100
        updatedColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(updatedColumn)
        
        let scrollView = NSScrollView()
        scrollView.documentView = personalTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add button
        let addButton = NSButton(title: "Add Selected Repository", target: self, action: #selector(addPersonalRepository))
        addButton.isEnabled = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(addButton)
        
        // Add scroll view directly to tab content with explicit constraints instead of stack view
        tabContent.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -12),
            
            addButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(equalTo: tabContent.bottomAnchor, constant: -16)
        ])
        
        // Force the table to size its columns to fill available width
        personalTableView.sizeLastColumnToFit()
        
        tabAddButtons.append(addButton)
        
        tabItem.view = tabContent
        tabView.addTabViewItem(tabItem)
    }
    
    private func setupOrganizationsTab() {
        let tabItem = NSTabViewItem(identifier: "organizations")
        tabItem.label = "Organizations"
        
        let tabContent = NSView()
        // Ensure tab content view expands to fill available tab space
        tabContent.frame = NSRect(x: 0, y: 0, width: 1000, height: 600)
        tabContent.autoresizingMask = [.width, .height]
        // Ensure autoresizing mask is used instead of constraints
        tabContent.translatesAutoresizingMaskIntoConstraints = true
        
        // Organization selector
        let orgStack = NSStackView()
        orgStack.orientation = .horizontal
        orgStack.spacing = 12
        orgStack.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(orgStack)
        
        let orgLabel = NSTextField(labelWithString: "Organization:")
        orgLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        orgLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        organizationsPopUp = NSPopUpButton()
        organizationsPopUp.target = self
        organizationsPopUp.action = #selector(organizationChanged)
        
        orgStack.addArrangedSubview(orgLabel)
        orgStack.addArrangedSubview(organizationsPopUp)
        orgStack.addArrangedSubview(NSView()) // Spacer
        
        // Filter field
        orgFilterField = NSTextField()
        orgFilterField.placeholderString = "Filter organization repositories..."
        orgFilterField.delegate = self
        orgFilterField.target = self
        orgFilterField.action = #selector(orgFilterChanged)
        orgFilterField.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(orgFilterField)
        
        // Repository table
        orgTableView = NSTableView()
        orgTableView.rowSizeStyle = .default
        orgTableView.selectionHighlightStyle = .regular
        orgTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        orgTableView.usesAlternatingRowBackgroundColors = true
        orgTableView.allowsColumnReordering = false
        orgTableView.allowsColumnResizing = true
        
        // Add columns with better width distribution
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Repository"
        nameColumn.width = 250
        nameColumn.minWidth = 150
        nameColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(nameColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Description"
        descriptionColumn.width = 250
        descriptionColumn.minWidth = 150
        descriptionColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(descriptionColumn)
        
        let visibilityColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("visibility"))
        visibilityColumn.title = "Visibility"
        visibilityColumn.width = 80
        visibilityColumn.minWidth = 60
        visibilityColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(visibilityColumn)
        
        let workflowsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflows"))
        workflowsColumn.title = "Workflows"
        workflowsColumn.width = 80
        workflowsColumn.minWidth = 60
        workflowsColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(workflowsColumn)
        
        let languageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("language"))
        languageColumn.title = "Language"
        languageColumn.width = 120
        languageColumn.minWidth = 80
        languageColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(languageColumn)
        
        let updatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("updated"))
        updatedColumn.title = "Updated"
        updatedColumn.width = 150
        updatedColumn.minWidth = 100
        updatedColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(updatedColumn)
        
        let scrollView = NSScrollView()
        scrollView.documentView = orgTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(scrollView)
        
        // Force the table to size its columns to fill available width
        orgTableView.sizeLastColumnToFit()
        
        // Add button
        let addButton = NSButton(title: "Add Selected Repository", target: self, action: #selector(addOrgRepository))
        addButton.isEnabled = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(addButton)
        tabAddButtons.append(addButton)
        
        // Setup explicit constraints
        NSLayoutConstraint.activate([
            orgStack.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            orgStack.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            orgStack.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            
            orgFilterField.topAnchor.constraint(equalTo: orgStack.bottomAnchor, constant: 12),
            orgFilterField.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            orgFilterField.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: orgFilterField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -12),
            
            addButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(equalTo: tabContent.bottomAnchor, constant: -16)
        ])
        
        tabItem.view = tabContent
        tabView.addTabViewItem(tabItem)
    }
    
    private func setupPublicSearchTab() {
        let tabItem = NSTabViewItem(identifier: "searchtest")
        tabItem.label = "Public Search"
        
        let tabContent = NSView()
        // ROBUST FIX: Force explicit content view sizing to prevent NSTabView layout bugs
        tabContent.frame = NSRect(x: 0, y: 0, width: 1000, height: 600)
        tabContent.autoresizingMask = [.width, .height]
        // Use constraints instead of autoresizing mask for more predictable behavior
        tabContent.translatesAutoresizingMaskIntoConstraints = false
        
        // Use stack view approach exactly like the working Monitored tab
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(mainStack)
        
        // Info label (minimal like Monitored tab)
        let infoLabel = NSTextField(labelWithString: "Search for public repositories by name, owner, or keywords")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(infoLabel)
        
        // Search controls
        let searchStack = NSStackView()
        searchStack.orientation = .horizontal
        searchStack.spacing = 8
        
        searchField = NSTextField()
        searchField.placeholderString = "Enter repository name, owner, or keywords..."
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        
        searchButton = NSButton(title: "Search", target: self, action: #selector(performRepositorySearch))
        searchButton.isEnabled = false
        
        searchStack.addArrangedSubview(searchField)
        searchStack.addArrangedSubview(searchButton)
        
        // Set search field to expand, button to stay fixed width
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchButton.setContentHuggingPriority(.required, for: .horizontal)
        
        mainStack.addArrangedSubview(searchStack)
        
        // Search results table - using exactly same structure as monitored table
        searchResultsTable = NSTableView()
        searchResultsTable.rowSizeStyle = .default
        searchResultsTable.selectionHighlightStyle = .regular
        searchResultsTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        searchResultsTable.usesAlternatingRowBackgroundColors = true
        searchResultsTable.allowsColumnReordering = false
        searchResultsTable.allowsColumnResizing = true
        
        // Add columns optimized for search results display
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Repository"
        nameColumn.width = 200
        nameColumn.minWidth = 150
        nameColumn.resizingMask = .autoresizingMask
        searchResultsTable.addTableColumn(nameColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Description"
        descriptionColumn.width = 300
        descriptionColumn.minWidth = 200
        descriptionColumn.resizingMask = .autoresizingMask
        searchResultsTable.addTableColumn(descriptionColumn)
        
        let languageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("language"))
        languageColumn.title = "Language"
        languageColumn.width = 100
        languageColumn.minWidth = 80
        languageColumn.resizingMask = .autoresizingMask
        searchResultsTable.addTableColumn(languageColumn)
        
        let starsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("stars"))
        starsColumn.title = "Stars"
        starsColumn.width = 80
        starsColumn.minWidth = 60
        starsColumn.resizingMask = .autoresizingMask
        searchResultsTable.addTableColumn(starsColumn)
        
        let workflowsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflows"))
        workflowsColumn.title = "Workflows"
        workflowsColumn.width = 80
        workflowsColumn.minWidth = 60
        workflowsColumn.resizingMask = .autoresizingMask
        searchResultsTable.addTableColumn(workflowsColumn)
        
        let scrollView = NSScrollView()
        scrollView.documentView = searchResultsTable
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add scroll view directly to tab content with explicit constraints instead of stack view - EXACTLY like Monitored tab
        tabContent.addSubview(scrollView)
        
        // Force the table to size its columns to fill available width
        searchResultsTable.sizeLastColumnToFit()
        
        // Add button - for adding search results to monitored repositories
        let addButton = NSButton(title: "Add Selected Repository", target: self, action: #selector(addSearchRepository))
        addButton.isEnabled = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(addButton)
        tabAddButtons.append(addButton)
        
        // CRITICAL FIX: Activate all constraints in single call to avoid ambiguous layout
        NSLayoutConstraint.activate([
            // Main stack positioning
            mainStack.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            
            // Scroll view positioning (depends on main stack)
            scrollView.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -12),
            
            // Button positioning (depends on scroll view)  
            addButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(equalTo: tabContent.bottomAnchor, constant: -16)
        ])
        
        // ROBUST FIX: Add explicit tab content constraints to prevent NSTabView sizing issues
        tabItem.view = tabContent
        tabView.addTabViewItem(tabItem)
        
        // After adding to tab view, constrain the content view to maintain proper size
        DispatchQueue.main.async { [weak self] in
            if let _ = self?.tabView.window {
                tabContent.widthAnchor.constraint(greaterThanOrEqualToConstant: 950).isActive = true
                // Remove fixed height constraint to allow flexible layout
            }
        }
    }
    
    private func setupMonitoredRepositoriesTab() {
        let tabItem = NSTabViewItem(identifier: "monitored")
        tabItem.label = "Monitored"
        
        let tabContent = NSView()
        tabContent.translatesAutoresizingMaskIntoConstraints = false
        
        // Main container stack view
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(mainStack)
        
        // Top section: Monitored repositories
        let topSection = NSStackView()
        topSection.orientation = .vertical
        topSection.spacing = 8
        mainStack.addArrangedSubview(topSection)
        
        // Monitored repositories header
        let repoHeaderLabel = NSTextField(labelWithString: "Monitored Repositories")
        repoHeaderLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        topSection.addArrangedSubview(repoHeaderLabel)
        
        let repoInfoLabel = NSTextField(labelWithString: "Select a repository to configure its workflow tracking")
        repoInfoLabel.font = NSFont.systemFont(ofSize: 11)
        repoInfoLabel.textColor = .secondaryLabelColor
        topSection.addArrangedSubview(repoInfoLabel)
        
        // Monitored repositories table
        monitoredTableView = NSTableView()
        monitoredTableView.rowSizeStyle = .default
        monitoredTableView.selectionHighlightStyle = .regular
        monitoredTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        monitoredTableView.usesAlternatingRowBackgroundColors = true
        monitoredTableView.allowsColumnReordering = false
        monitoredTableView.allowsColumnResizing = true
        
        // Add columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Repository"
        nameColumn.width = 250
        nameColumn.minWidth = 150
        nameColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(nameColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Description"
        descriptionColumn.width = 200
        descriptionColumn.minWidth = 150
        descriptionColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(descriptionColumn)
        
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 80
        typeColumn.minWidth = 70
        typeColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(typeColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Last Status"
        statusColumn.width = 120
        statusColumn.minWidth = 100
        statusColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(statusColumn)
        
        let workflowsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflows"))
        workflowsColumn.title = "Workflows"
        workflowsColumn.width = 150
        workflowsColumn.minWidth = 100
        workflowsColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(workflowsColumn)
        
        let addedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("added"))
        addedColumn.title = "Added"
        addedColumn.width = 120
        addedColumn.minWidth = 100
        addedColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(addedColumn)
        
        let repoScrollView = NSScrollView()
        repoScrollView.documentView = monitoredTableView
        repoScrollView.hasVerticalScroller = true
        repoScrollView.borderType = .lineBorder
        repoScrollView.autohidesScrollers = false
        repoScrollView.hasHorizontalScroller = true
        repoScrollView.translatesAutoresizingMaskIntoConstraints = false
        topSection.addArrangedSubview(repoScrollView)
        
        // Repository action buttons
        let repoButtonStack = NSStackView()
        repoButtonStack.orientation = .horizontal
        repoButtonStack.spacing = 12
        topSection.addArrangedSubview(repoButtonStack)
        
        monitoredRemoveButton = NSButton(title: "Remove Selected Repository", target: self, action: #selector(removeRepository))
        monitoredRemoveButton.isEnabled = false
        
        repoButtonStack.addArrangedSubview(monitoredRemoveButton)
        repoButtonStack.addArrangedSubview(NSView()) // Spacer
        
        // Bottom section: Workflow configuration
        let bottomSection = NSStackView()
        bottomSection.orientation = .vertical
        bottomSection.spacing = 8
        mainStack.addArrangedSubview(bottomSection)
        
        // Workflow configuration header
        workflowTableLabel = NSTextField(labelWithString: "Workflow Configuration")
        workflowTableLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        bottomSection.addArrangedSubview(workflowTableLabel)
        
        let workflowInfoLabel = NSTextField(labelWithString: "Configure which workflows to track for the selected repository")
        workflowInfoLabel.font = NSFont.systemFont(ofSize: 11)
        workflowInfoLabel.textColor = .secondaryLabelColor
        bottomSection.addArrangedSubview(workflowInfoLabel)
        
        // Workflow table
        workflowTableView = NSTableView()
        workflowTableView.rowSizeStyle = .default
        workflowTableView.selectionHighlightStyle = .none // No selection needed for workflow table
        workflowTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        workflowTableView.usesAlternatingRowBackgroundColors = true
        workflowTableView.allowsColumnReordering = false
        workflowTableView.allowsColumnResizing = true
        workflowTableView.allowsEmptySelection = true
        workflowTableView.allowsMultipleSelection = false
        
        // Workflow table columns
        let workflowNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflowName"))
        workflowNameColumn.title = "Workflow Name"
        workflowNameColumn.width = 300
        workflowNameColumn.minWidth = 200
        workflowNameColumn.resizingMask = .autoresizingMask
        workflowTableView.addTableColumn(workflowNameColumn)
        
        let workflowStateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflowState"))
        workflowStateColumn.title = "State"
        workflowStateColumn.width = 100
        workflowStateColumn.minWidth = 80
        workflowStateColumn.resizingMask = .autoresizingMask
        workflowTableView.addTableColumn(workflowStateColumn)
        
        let workflowEnabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("workflowEnabled"))
        workflowEnabledColumn.title = "Track"
        workflowEnabledColumn.width = 80
        workflowEnabledColumn.minWidth = 60
        workflowEnabledColumn.resizingMask = .autoresizingMask
        workflowTableView.addTableColumn(workflowEnabledColumn)
        
        let workflowScrollView = NSScrollView()
        workflowScrollView.documentView = workflowTableView
        workflowScrollView.hasVerticalScroller = true
        workflowScrollView.borderType = .lineBorder
        workflowScrollView.autohidesScrollers = false
        workflowScrollView.hasHorizontalScroller = true
        workflowScrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomSection.addArrangedSubview(workflowScrollView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Main stack positioning
            mainStack.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: tabContent.bottomAnchor, constant: -16),
            
            // Repository table height and width
            repoScrollView.heightAnchor.constraint(equalToConstant: 250),
            repoScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 900),
            
            // Workflow table height and width
            workflowScrollView.heightAnchor.constraint(equalToConstant: 200),
            workflowScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 900)
        ])
        
        tabItem.view = tabContent
        tabView.addTabViewItem(tabItem)
        
        // Add width constraints to prevent narrow layout issues
        DispatchQueue.main.async { [weak self] in
            if let _ = self?.tabView.window {
                tabContent.widthAnchor.constraint(greaterThanOrEqualToConstant: 950).isActive = true
                tabContent.heightAnchor.constraint(greaterThanOrEqualToConstant: 600).isActive = true
            }
        }
        
        // Initially disable workflow section until a repository is selected
        updateWorkflowTableState()
    }
    
    // MARK: - Workflow Table Management
    
    private func updateWorkflowTableState() {
        let hasSelection = selectedRepository != nil
        workflowTableView.isEnabled = hasSelection
        
        if hasSelection {
            workflowTableLabel.stringValue = "Workflow Configuration - \(selectedRepository?.fullName ?? "")"
            workflowTableLabel.textColor = .labelColor
        } else {
            workflowTableLabel.stringValue = "Workflow Configuration - Select a repository"
            workflowTableLabel.textColor = .secondaryLabelColor
        }
    }
    
    private func loadWorkflowsForSelectedRepository() {
        guard let repository = selectedRepository else {
            currentWorkflows = []
            workflowTableView.reloadData()
            return
        }
        
        StatusBarDebugger.shared.log(.network, "Loading workflows for repository", context: ["repository": repository.fullName])
        
        // Fetch workflows from GitHub API
        gitHubClient.getWorkflows(owner: repository.owner, repo: repository.name) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let workflows):
                    let activeWorkflows = workflows.workflows.filter { $0.state == "active" }
                    self?.currentWorkflows = activeWorkflows
                    self?.workflowTableView.reloadData()
                    StatusBarDebugger.shared.log(.network, "Loaded total workflows for repository", context: ["count": workflows.workflows.count, "repository": repository.fullName])
                    StatusBarDebugger.shared.log(.network, "Filtered to active workflows", context: ["count": activeWorkflows.count, "workflows": activeWorkflows.map { $0.name }])
                    
                case .failure(let error):
                    StatusBarDebugger.shared.log(.error, "Failed to load workflows for repository", context: ["repository": repository.fullName, "error": error.localizedDescription])
                    self?.currentWorkflows = []
                    self?.workflowTableView.reloadData()
                }
            }
        }
    }
    
    private func toggleWorkflowTracking(for workflowName: String) {
        guard let repository = selectedRepository else { 
            StatusBarDebugger.shared.log(.error, "No repository selected for workflow toggle")
            return 
        }
        
        StatusBarDebugger.shared.log(.state, "Toggling workflow for repository", context: ["workflow": workflowName, "repository": repository.fullName])
        
        // Update the repository's workflow tracking
        var updatedRepository = repository
        let currentlyTracked = repository.isWorkflowTracked(workflowName)
        StatusBarDebugger.shared.log(.state, "Current tracking state for workflow", context: ["workflow": workflowName, "tracked": currentlyTracked])
        
        // Initialize trackedWorkflows if empty (first configuration)
        if updatedRepository.trackedWorkflows.isEmpty {
            StatusBarDebugger.shared.log(.state, "Initializing workflow tracking (was empty)")
            // Set all current workflows to their default state (true)
            for workflow in currentWorkflows {
                updatedRepository.trackedWorkflows[workflow.name] = true
            }
        }
        
        // Toggle the specific workflow
        updatedRepository.trackedWorkflows[workflowName] = !currentlyTracked
        StatusBarDebugger.shared.log(.state, "New tracking state for workflow", context: ["workflow": workflowName, "tracked": !currentlyTracked])
        
        // Save the updated repository
        let success = repositoryManager.setTrackedWorkflows(for: repository.fullName, workflows: updatedRepository.trackedWorkflows)
        guard success else {
            StatusBarDebugger.shared.log(.error, "Failed to save workflow configuration", context: ["repository": repository.fullName])
            return
        }
        
        // Update the monitored repositories list
        if let index = monitoredRepositories.firstIndex(where: { $0.fullName == repository.fullName }) {
            monitoredRepositories[index] = updatedRepository
            selectedRepository = updatedRepository
        }
        
        // Reload both tables
        monitoredTableView.reloadData()
        workflowTableView.reloadData()
        
        StatusBarDebugger.shared.log(.state, "Toggled workflow tracking", context: ["workflow": workflowName, "tracked": !currentlyTracked, "repository": repository.fullName])
    }
    
    // MARK: - Data Loading Methods
    
    private func loadData() {
        // Load monitored repositories (always available without authentication)
        monitoredRepositories = repositoryManager.getMonitoredRepositories()
        monitoredTableView.reloadData()
        
        // Load data for other tabs if authenticated
        if GitHubOAuthConfig.isConfigured {
            loadPersonalRepositories()
            loadUserOrganizations()
        }
    }
    
    private func loadPersonalRepositories() {
        showLoading(true)
        
        gitHubClient.getRepositories { [weak self] result in
            DispatchQueue.main.async {
                self?.showLoading(false)
                
                switch result {
                case .success(let repositories):
                    self?.personalRepositories = repositories
                    self?.personalTableView.reloadData()
                    // Preload workflow status for all repositories to avoid lag when scrolling
                    self?.preloadWorkflowStatus(for: repositories)
                    
                case .failure(let error):
                    self?.showError("Failed to fetch personal repositories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadUserOrganizations() {
        StatusBarDebugger.shared.log(.network, "🔄 Starting loadUserOrganizations")
        gitHubClient.getUserOrganizations { [weak self] result in
            StatusBarDebugger.shared.log(.network, "📡 getUserOrganizations callback received")
            DispatchQueue.main.async {
                StatusBarDebugger.shared.log(.network, "🎯 In main dispatch queue for organizations update")
                switch result {
                case .success(let organizations):
                    StatusBarDebugger.shared.log(.network, "✅ Organizations success", context: [
                        "count": "\(organizations.count)",
                        "orgs": organizations.map { $0.login }
                    ])
                    
                    self?.userOrganizations = organizations
                    StatusBarDebugger.shared.log(.network, "🗑️ Clearing organizations popup")
                    self?.organizationsPopUp.removeAllItems()
                    
                    if organizations.isEmpty {
                        StatusBarDebugger.shared.log(.network, "❌ No organizations - showing empty state")
                        self?.organizationsPopUp.addItem(withTitle: "No organizations")
                        self?.organizationsPopUp.isEnabled = false
                    } else if organizations.count == 1 {
                        // Auto-select single organization for better UX
                        let singleOrg = organizations[0]
                        StatusBarDebugger.shared.log(.network, "🎯 Single organization - auto-selecting", context: ["org": singleOrg.login])
                        self?.organizationsPopUp.addItem(withTitle: singleOrg.login)
                        self?.organizationsPopUp.selectItem(at: 0)
                        self?.organizationsPopUp.isEnabled = true
                        
                        // Automatically load repositories for the single organization
                        self?.loadOrganizationRepositories(for: singleOrg.login)
                    } else {
                        // Multiple organizations - show dropdown with selection required
                        StatusBarDebugger.shared.log(.network, "📋 Multiple organizations - building dropdown")
                        self?.organizationsPopUp.addItem(withTitle: "Select organization...")
                        StatusBarDebugger.shared.log(.network, "➕ Added 'Select organization...' item")
                        
                        for (index, org) in organizations.enumerated() {
                            self?.organizationsPopUp.addItem(withTitle: org.login)
                            StatusBarDebugger.shared.log(.network, "➕ Added organization item", context: [
                                "index": "\(index + 1)",
                                "org": org.login
                            ])
                        }
                        
                        self?.organizationsPopUp.isEnabled = true
                        StatusBarDebugger.shared.log(.network, "✅ Organizations popup setup complete", context: [
                            "finalItemCount": "\(self?.organizationsPopUp.numberOfItems ?? 0)",
                            "finalItems": self?.organizationsPopUp.itemTitles ?? [],
                            "isEnabled": "\(self?.organizationsPopUp.isEnabled ?? false)"
                        ])
                    }
                    
                case .failure(let error):
                    self?.organizationsPopUp.removeAllItems()
                    self?.organizationsPopUp.addItem(withTitle: "Failed to load organizations")
                    self?.organizationsPopUp.isEnabled = false
                    StatusBarDebugger.shared.log(.error, "Failed to load organizations", context: ["error": error.localizedDescription])
                }
            }
        }
    }
    
    private func loadOrganizationRepositories(for orgLogin: String) {
        StatusBarDebugger.shared.log(.network, "🏢 Starting loadOrganizationRepositories", context: ["org": orgLogin])
        showLoading(true)
        
        gitHubClient.getOrganizationRepositories(org: orgLogin) { [weak self] result in
            StatusBarDebugger.shared.log(.network, "📡 getOrganizationRepositories callback received", context: ["org": orgLogin])
            DispatchQueue.main.async {
                StatusBarDebugger.shared.log(.network, "🎯 In main dispatch queue for org repos update")
                self?.showLoading(false)
                
                switch result {
                case .success(let repositories):
                    StatusBarDebugger.shared.log(.network, "✅ Organization repositories success", context: [
                        "org": orgLogin,
                        "count": "\(repositories.count)",
                        "repos": repositories.map { $0.name }
                    ])
                    self?.selectedOrgRepositories = repositories
                    self?.orgTableView.reloadData()
                    StatusBarDebugger.shared.log(.network, "📊 Organization table reloaded", context: [
                        "org": orgLogin,
                        "tableRows": "\(self?.orgTableView.numberOfRows ?? 0)"
                    ])
                    // Preload workflow status for all repositories to avoid lag when scrolling
                    self?.preloadWorkflowStatus(for: repositories)
                    
                case .failure(let error):
                    StatusBarDebugger.shared.log(.error, "❌ Failed to load organization repositories", context: [
                        "org": orgLogin,
                        "error": error.localizedDescription
                    ])
                    self?.showError("Failed to fetch repositories for \(orgLogin): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showLoading(_ show: Bool) {
        loadingIndicator?.isHidden = !show
        if show {
            loadingIndicator?.startAnimation(nil)
        } else {
            loadingIndicator?.stopAnimation(nil)
        }
        refreshButton?.isEnabled = !show
        clearCacheButton?.isEnabled = !show
    }
    
    private func showAuthenticationInfo() {
        // No longer shows a blocking dialog - just logs that authentication is not available
        StatusBarDebugger.shared.log(.menu, "Repository settings opened without GitHub authentication - available repositories will be empty")
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        if let window = window {
            alert.beginSheetModal(for: window)
        }
    }
    
    // MARK: - Action Methods
    
    // Personal Repositories Tab Actions
    @objc private func personalFilterChanged() {
        personalTableView.reloadData()
    }
    
    @objc private func personalSortChanged() {
        personalRepositories = sortRepositories(personalRepositories, by: personalSortButton.indexOfSelectedItem)
        personalTableView.reloadData()
    }
    
    @objc private func addPersonalRepository() {
        let selectedRow = personalTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredPersonalRepositories().count else { return }
        
        let repository = filteredPersonalRepositories()[selectedRow]
        addRepositoryToMonitored(repository)
    }
    
    // Organizations Tab Actions
    @objc private func organizationChanged() {
        let selectedIndex = organizationsPopUp.indexOfSelectedItem
        StatusBarDebugger.shared.log(.menu, "🎯 organizationChanged triggered", context: [
            "selectedIndex": "\(selectedIndex)",
            "totalOrgs": "\(userOrganizations.count)",
            "popupItems": organizationsPopUp.itemTitles
        ])
        
        // Handle different organization selection scenarios
        if userOrganizations.count == 1 {
            // Single organization case - selectedIndex 0 is the organization
            StatusBarDebugger.shared.log(.menu, "📍 Single organization case")
            guard selectedIndex == 0 else {
                StatusBarDebugger.shared.log(.menu, "⚠️ Invalid selection - clearing table")
                selectedOrgRepositories = []
                orgTableView.reloadData()
                return
            }
            let selectedOrg = userOrganizations[0]
            StatusBarDebugger.shared.log(.menu, "🚀 Loading repositories for single org", context: ["org": selectedOrg.login])
            loadOrganizationRepositories(for: selectedOrg.login)
        } else {
            // Multiple organizations case - selectedIndex 0 is "Select organization..."
            StatusBarDebugger.shared.log(.menu, "📍 Multiple organizations case")
            guard selectedIndex > 0, selectedIndex <= userOrganizations.count else {
                StatusBarDebugger.shared.log(.menu, "⚠️ Invalid selection or 'Select organization...' - clearing table", context: [
                    "selectedIndex": "\(selectedIndex)",
                    "validRange": "1 to \(userOrganizations.count)"
                ])
                selectedOrgRepositories = []
                orgTableView.reloadData()
                return
            }
            let selectedOrg = userOrganizations[selectedIndex - 1]
            StatusBarDebugger.shared.log(.menu, "🚀 Loading repositories for selected org", context: [
                "org": selectedOrg.login,
                "selectedIndex": "\(selectedIndex)"
            ])
            loadOrganizationRepositories(for: selectedOrg.login)
        }
    }
    
    @objc private func orgFilterChanged() {
        orgTableView.reloadData()
    }
    
    @objc private func addOrgRepository() {
        let selectedRow = orgTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredOrgRepositories().count else { return }
        
        let repository = filteredOrgRepositories()[selectedRow]
        addRepositoryToMonitored(repository)
    }
    
    // Public Search Tab Actions
    @objc private func searchFieldChanged() {
        let text = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        searchButton.isEnabled = !text.isEmpty && text.count >= 2
    }
    
    @objc private func performRepositorySearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty && query.count >= 2 else {
            showError("Please enter at least 2 characters to search")
            return
        }
        
        guard !isSearching else { return }
        
        StatusBarDebugger.shared.log(.menu, "Performing repository search", context: ["query": query])
        
        isSearching = true
        searchButton.title = "Searching..."
        searchButton.isEnabled = false
        
        gitHubClient.searchPublicRepositories(query: query, sort: "stars", order: "desc", page: 1, perPage: 20) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isSearching = false
                self.searchButton.title = "Search"
                self.searchButton.isEnabled = true
                
                switch result {
                case .success(let searchResponse):
                    self.searchResults = searchResponse.items
                    self.searchResultsTable.reloadData()
                    // Preload workflow status for search results to avoid lag when scrolling
                    self.preloadWorkflowStatus(for: searchResponse.items)
                    
                    StatusBarDebugger.shared.log(.menu, "Repository search completed", context: [
                        "query": query,
                        "results": searchResponse.items.count,
                        "totalCount": searchResponse.totalCount
                    ])
                    
                case .failure(let error):
                    StatusBarDebugger.shared.log(.error, "Repository search failed", context: [
                        "query": query,
                        "error": error.localizedDescription
                    ])
                    
                    self.showError("Search failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func addSearchRepository() {
        let selectedRow = searchResultsTable.selectedRow
        guard selectedRow >= 0 && selectedRow < searchResults.count else { return }
        
        let repository = searchResults[selectedRow]
        addRepositoryToMonitored(repository)
    }
    
    // Monitored Repositories Tab Actions
    
    @objc private func removeRepository() {
        let selectedRow = monitoredTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < monitoredRepositories.count else { return }
        
        let repository = monitoredRepositories[selectedRow]
        
        if repositoryManager.removeRepository(repository) {
            monitoredRepositories = repositoryManager.getMonitoredRepositories()
            monitoredTableView.reloadData()
            
            // Clear selection and update state
            monitoredTableView.deselectAll(nil)
            selectedRepository = nil
            monitoredRemoveButton.isEnabled = false
            updateWorkflowTableState()
            currentWorkflows = []
            workflowTableView.reloadData()
            
            StatusBarDebugger.shared.log(.menu, "Repository removed from monitoring", context: ["repo": repository.fullName])
        }
    }
    
    // Common Actions
    @objc private func refreshCurrentTab() {
        guard let currentTab = tabView.selectedTabViewItem?.identifier as? String else { return }
        
        StatusBarDebugger.shared.log(.menu, "Refreshing current tab", context: ["tab": currentTab])
        
        switch currentTab {
        case "personal":
            if GitHubOAuthConfig.isConfigured {
                loadPersonalRepositories()
            }
        case "organizations":
            if GitHubOAuthConfig.isConfigured {
                loadUserOrganizations()
                if organizationsPopUp.indexOfSelectedItem > 0 {
                    organizationChanged()
                }
            }
        case "searchtest":
            // Clear previous search results
            searchResults = []
            searchResultsTable.reloadData()
            searchField.stringValue = ""
            searchButton.isEnabled = false
        case "monitored":
            // Skip data reload during tab switching to prevent layout race conditions
            // Data is already loaded in loadData() and updated when repositories change
            break
        default:
            break
        }
    }
    
    @objc private func clearAllCaches() {
        StatusBarDebugger.shared.log(.menu, "Clear cache button clicked")
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Clear All Cached Data"
        alert.informativeText = "This will clear all cached repository data and workflow status. The next time you open repository tabs, fresh data will be fetched from GitHub. Continue?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Clear Cache")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Clear all caches
            gitHubClient.clearAllCaches()
            WorkflowDetectionService.shared.clearCache()
            
            // Show success message
            let successAlert = NSAlert()
            successAlert.messageText = "Cache Cleared"
            successAlert.informativeText = "All cached data has been cleared successfully. Repository data will be refreshed from GitHub on next load."
            successAlert.alertStyle = .informational
            successAlert.addButton(withTitle: "OK")
            successAlert.runModal()
            
            StatusBarDebugger.shared.log(.menu, "All caches cleared successfully")
        }
    }
    
    @objc private func closeWindow() {
        // Add debug logging
        StatusBarDebugger.shared.log(.menu, "Repository settings close button clicked")
        
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else {
                StatusBarDebugger.shared.log(.error, "Repository settings window is nil during close")
                return
            }
            
            StatusBarDebugger.shared.log(.menu, "Closing repository settings window")
            
            // Call close on the window - this will trigger the delegate method in StatusBarManager
            window.close()
        }
    }
    
    // MARK: - Helper Methods
    
    private func addRepositoryToMonitored(_ repository: Repository) {
        StatusBarDebugger.shared.log(.menu, "Adding repository to monitoring", context: ["repo": repository.fullName])
        
        // Check if repository is already monitored
        if monitoredRepositories.contains(where: { $0.fullName.lowercased() == repository.fullName.lowercased() }) {
            showError("Repository '\(repository.fullName)' is already being monitored")
            return
        }
        
        let monitoredRepo = MonitoredRepository(from: repository)
        
        if repositoryManager.addRepository(monitoredRepo) {
            monitoredRepositories = repositoryManager.getMonitoredRepositories()
            monitoredTableView.reloadData()
            
            StatusBarDebugger.shared.log(.menu, "Successfully added repository to monitoring", context: ["repo": repository.fullName])
            
            // Show success message
            let alert = NSAlert()
            alert.messageText = "Repository Added"
            alert.informativeText = "Successfully added '\(repository.fullName)' to monitoring list"
            alert.addButton(withTitle: "OK")
            if let window = window {
                alert.beginSheetModal(for: window)
            }
        } else {
            showError("Failed to add repository to monitoring list")
        }
    }
    
    private func filteredPersonalRepositories() -> [Repository] {
        let filter = personalFilterField.stringValue.lowercased()
        if filter.isEmpty {
            return personalRepositories
        }
        return personalRepositories.filter { repo in
            repo.fullName.lowercased().contains(filter) ||
            (repo.description?.lowercased().contains(filter) ?? false) ||
            (repo.language?.lowercased().contains(filter) ?? false)
        }
    }
    
    private func filteredOrgRepositories() -> [Repository] {
        let filter = orgFilterField.stringValue.lowercased()
        if filter.isEmpty {
            return selectedOrgRepositories
        }
        return selectedOrgRepositories.filter { repo in
            repo.fullName.lowercased().contains(filter) ||
            (repo.description?.lowercased().contains(filter) ?? false) ||
            (repo.language?.lowercased().contains(filter) ?? false)
        }
    }
    
    private func sortRepositories(_ repositories: [Repository], by sortIndex: Int) -> [Repository] {
        switch sortIndex {
        case 0: // Name (A-Z)
            return repositories.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case 1: // Name (Z-A)
            return repositories.sorted { $0.name.lowercased() > $1.name.lowercased() }
        case 2: // Updated (Recent) - Note: we don't have updatedAt field, so sort by name for now
            return repositories.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case 3: // Updated (Oldest)
            return repositories.sorted { $0.name.lowercased() > $1.name.lowercased() }
        case 4: // Stars (Most)
            return repositories.sorted { ($0.stargazersCount ?? 0) > ($1.stargazersCount ?? 0) }
        case 5: // Stars (Least)
            return repositories.sorted { ($0.stargazersCount ?? 0) < ($1.stargazersCount ?? 0) }
        default:
            return repositories
        }
    }
    
    private func updateTabButtonStates() {
        // Update button states based on current tab selection
        guard let currentTab = tabView.selectedTabViewItem?.identifier as? String else { return }
        
        switch currentTab {
        case "personal":
            tabAddButtons[0].isEnabled = personalTableView.selectedRow >= 0
        case "organizations":
            tabAddButtons[1].isEnabled = orgTableView.selectedRow >= 0
        case "searchtest":
            tabAddButtons[2].isEnabled = searchResultsTable.selectedRow >= 0
        case "monitored":
            let hasSelection = monitoredTableView.selectedRow >= 0
            monitoredRemoveButton.isEnabled = hasSelection
        default:
            break
        }
    }
    
    // Helper method to reload a specific repository row after workflow detection
    private func reloadRepositoryRow(repository: Repository) {
        // Find which table contains this repository and reload the appropriate row
        
        // Check personal repositories
        if let personalIndex = filteredPersonalRepositories().firstIndex(where: { $0.fullName == repository.fullName }) {
            personalTableView.reloadData(forRowIndexes: IndexSet(integer: personalIndex), columnIndexes: IndexSet(0..<personalTableView.numberOfColumns))
            return
        }
        
        // Check organization repositories  
        if let orgIndex = filteredOrgRepositories().firstIndex(where: { $0.fullName == repository.fullName }) {
            orgTableView.reloadData(forRowIndexes: IndexSet(integer: orgIndex), columnIndexes: IndexSet(0..<orgTableView.numberOfColumns))
            return
        }
        
        // Check search results
        if let searchIndex = searchResults.firstIndex(where: { $0.fullName == repository.fullName }) {
            searchResultsTable.reloadData(forRowIndexes: IndexSet(integer: searchIndex), columnIndexes: IndexSet(0..<searchResultsTable.numberOfColumns))
            return
        }
    }
    
    // MARK: - Workflow Detection Preloading
    
    private func preloadWorkflowStatus(for repositories: [Repository]) {
        // Only preload for repositories that don't already have cached status
        let pendingRepositories = repositories.filter { repository in
            // Only check viable repositories that don't have cached workflow status
            repository.isBasicallyViable && WorkflowDetectionService.shared.getCachedWorkflowStatus(for: repository) == nil
        }
        
        StatusBarDebugger.shared.log(.network, "Preloading workflow status", context: ["repositoryCount": pendingRepositories.count])
        
        // Trigger workflow detection for all pending repositories
        // The WorkflowDetectionService will handle batching and rate limiting
        for repository in pendingRepositories {
            repository.checkWorkflowViability { [weak self] hasWorkflows in
                DispatchQueue.main.async {
                    // Reload the specific row to update the UI
                    self?.reloadRepositoryRow(repository: repository)
                }
            }
        }
    }
    
}

// MARK: - NSTextFieldDelegate

extension RepositorySettingsWindow: NSTextFieldDelegate {
    
    public func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        
        if textField == searchField {
            searchFieldChanged()
        } else if textField == personalFilterField {
            personalFilterChanged()
        } else if textField == orgFilterField {
            orgFilterChanged()
        }
    }
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle Enter key for different text fields
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let textField = control as? NSTextField {
                if textField == searchField && searchButton.isEnabled {
                    performRepositorySearch()
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Table View Data Source & Delegate

extension RepositorySettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == personalTableView {
            return filteredPersonalRepositories().count
        } else if tableView == orgTableView {
            return filteredOrgRepositories().count
        } else if tableView == searchResultsTable {
            return searchResults.count
        } else if tableView == monitoredTableView {
            return monitoredRepositories.count
        } else if tableView == workflowTableView {
            return currentWorkflows.count
        }
        return 0
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        let cellView = NSTableCellView()
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        if tableView == personalTableView {
            let repositories = filteredPersonalRepositories()
            guard row < repositories.count else { return nil }
            let repository = repositories[row]
            
            configureRepositoryCell(textField: textField, repository: repository, identifier: identifier.rawValue)
            
        } else if tableView == orgTableView {
            let repositories = filteredOrgRepositories()
            guard row < repositories.count else { return nil }
            let repository = repositories[row]
            
            configureRepositoryCell(textField: textField, repository: repository, identifier: identifier.rawValue)
            
        } else if tableView == searchResultsTable {
            guard row < searchResults.count else { return nil }
            let repository = searchResults[row]
            
            configureSearchResultCell(textField: textField, repository: repository, identifier: identifier.rawValue)
            
        } else if tableView == monitoredTableView {
            guard row < monitoredRepositories.count else { return nil }
            let repository = monitoredRepositories[row]
            
            configureMonitoredCell(textField: textField, repository: repository, identifier: identifier.rawValue)
            
        } else if tableView == workflowTableView {
            guard row < currentWorkflows.count else { return nil }
            let workflow = currentWorkflows[row]
            
            return configureWorkflowCell(workflow: workflow, identifier: identifier.rawValue, row: row)
        }
        
        cellView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    private func configureRepositoryCell(textField: NSTextField, repository: Repository, identifier: String) {
        // Determine repository status for UI styling
        let isViable = repository.isWorkflowMonitoringViable
        let isPending = repository.isWorkflowStatusPending
        
        // Choose colors based on status
        let baseTextColor: NSColor
        let secondaryTextColor: NSColor
        
        if isPending {
            // Pending workflow detection - use muted colors and show loading indication
            baseTextColor = .systemBlue
            secondaryTextColor = .systemBlue.withAlphaComponent(0.7)
        } else if isViable {
            // Repository is viable - normal colors
            baseTextColor = .labelColor
            secondaryTextColor = .secondaryLabelColor
        } else {
            // Repository is not viable - greyed out colors
            baseTextColor = .tertiaryLabelColor
            secondaryTextColor = .quaternaryLabelColor
        }
        
        // Note: Workflow detection is now handled by preloading when repositories are loaded
        // This prevents lag when scrolling and avoids duplicate API calls
        
        switch identifier {
        case "name":
            // Repository name should always be clean - workflow status is shown in the workflows column
            textField.stringValue = repository.fullName
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            textField.textColor = baseTextColor
        case "visibility":
            textField.stringValue = repository.private ? "Private" : "Public"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
        case "workflows":
            if repository.archived == true {
                textField.stringValue = "—"
                textField.textColor = .tertiaryLabelColor
            } else if repository.disabled == true {
                textField.stringValue = "—"
                textField.textColor = .tertiaryLabelColor
            } else if isPending {
                textField.stringValue = "?"
                textField.textColor = .systemBlue
            } else if isViable {
                textField.stringValue = "✓"
                textField.textColor = .systemGreen
            } else {
                textField.stringValue = "✗"
                textField.textColor = .systemRed
            }
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.alignment = .center
        case "language":
            textField.stringValue = repository.language ?? "—"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
        case "description":
            let descriptionText = repository.description ?? "No description"
            textField.stringValue = descriptionText
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = repository.description != nil ? baseTextColor : secondaryTextColor
            textField.lineBreakMode = .byTruncatingTail
        case "updated":
            textField.stringValue = "Recently" // We don't have updated date, placeholder
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
        default:
            break
        }
    }
    
    private func configureSearchResultCell(textField: NSTextField, repository: Repository, identifier: String) {
        // Determine repository status for UI styling
        let isViable = repository.isWorkflowMonitoringViable
        let isPending = repository.isWorkflowStatusPending
        
        // Choose colors based on status
        let baseTextColor: NSColor
        let secondaryTextColor: NSColor
        
        if isPending {
            // Pending workflow detection - use muted colors and show loading indication
            baseTextColor = .systemBlue
            secondaryTextColor = .systemBlue.withAlphaComponent(0.7)
        } else if isViable {
            // Repository is viable - normal colors
            baseTextColor = .labelColor
            secondaryTextColor = .secondaryLabelColor
        } else {
            // Repository is not viable - greyed out colors
            baseTextColor = .tertiaryLabelColor
            secondaryTextColor = .quaternaryLabelColor
        }
        
        // Note: Workflow detection is now handled by preloading when repositories are loaded
        // This prevents lag when scrolling and avoids duplicate API calls
        
        switch identifier {
        case "name":
            // Repository name should always be clean - workflow status is shown in the workflows column
            textField.stringValue = repository.fullName
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            textField.textColor = baseTextColor
        case "description":
            let descriptionText = repository.description ?? "No description"
            textField.stringValue = descriptionText
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = repository.description != nil ? baseTextColor : secondaryTextColor
            textField.lineBreakMode = .byTruncatingTail
        case "language":
            textField.stringValue = repository.language ?? "—"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
        case "stars":
            if let stars = repository.stargazersCount {
                textField.stringValue = stars >= 1000 ? String(format: "%.1fk", Double(stars) / 1000) : "\(stars)"
            } else {
                textField.stringValue = "0"
            }
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
            textField.alignment = .right
        case "workflows":
            if repository.archived == true {
                textField.stringValue = "—"
                textField.textColor = .tertiaryLabelColor
            } else if repository.disabled == true {
                textField.stringValue = "—"
                textField.textColor = .tertiaryLabelColor
            } else if isPending {
                textField.stringValue = "?"
                textField.textColor = .systemBlue
            } else if isViable {
                textField.stringValue = "✓"
                textField.textColor = .systemGreen
            } else {
                textField.stringValue = "✗"
                textField.textColor = .systemRed
            }
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.alignment = .center
        default:
            break
        }
    }
    
    private func configureMonitoredCell(textField: NSTextField, repository: MonitoredRepository, identifier: String) {
        switch identifier {
        case "name":
            textField.stringValue = repository.fullName
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        case "description":
            textField.stringValue = repository.description ?? "No description"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = repository.description != nil ? .labelColor : .secondaryLabelColor
            textField.lineBreakMode = .byTruncatingTail
        case "type":
            textField.stringValue = repository.isPrivate ? "Private" : "Public"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
        case "status":
            textField.stringValue = "Monitoring" // Placeholder - could show actual status
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .systemGreen
        case "workflows":
            if repository.hasSpecificWorkflowsConfigured {
                let trackedCount = repository.trackedWorkflowNames.count
                let totalCount = repository.allConfiguredWorkflowNames.count
                textField.stringValue = "\(trackedCount)/\(totalCount) configured"
                textField.font = NSFont.systemFont(ofSize: 11)
                textField.textColor = trackedCount > 0 ? .systemBlue : .secondaryLabelColor
            } else {
                textField.stringValue = "All workflows"
                textField.font = NSFont.systemFont(ofSize: 11)
                textField.textColor = .secondaryLabelColor
            }
        case "added":
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            textField.stringValue = formatter.string(from: repository.addedAt)
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
        default:
            break
        }
    }
    
    private func configureWorkflowCell(workflow: Workflow, identifier: String, row: Int) -> NSView? {
        guard let repository = selectedRepository else { return nil }
        
        let cellView = NSTableCellView()
        
        switch identifier {
        case "workflowName":
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.stringValue = workflow.name
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
        case "workflowState":
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.stringValue = workflow.state.capitalized
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = workflow.state == "active" ? .systemGreen : .secondaryLabelColor
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
        case "workflowEnabled":
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(workflowCheckboxToggled(_:)))
            let isTracked = repository.isWorkflowTracked(workflow.name)
            checkbox.state = isTracked ? .on : .off
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            
            // Store workflow name for the toggle action
            checkbox.tag = row
            
            cellView.addSubview(checkbox)
            NSLayoutConstraint.activate([
                checkbox.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
                checkbox.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
        default:
            break
        }
        
        return cellView
    }
    
    @objc private func workflowCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        StatusBarDebugger.shared.log(.state, "Workflow checkbox toggled", context: ["row": row, "workflowCount": currentWorkflows.count])
        
        guard row >= 0 && row < currentWorkflows.count else { 
            StatusBarDebugger.shared.log(.error, "Invalid row index for workflows", context: ["row": row, "workflowCount": currentWorkflows.count])
            return 
        }
        
        let workflow = currentWorkflows[row]
        StatusBarDebugger.shared.log(.state, "Toggling workflow", context: ["workflow": workflow.name])
        toggleWorkflowTracking(for: workflow.name)
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            if tableView == monitoredTableView {
                let selectedRow = tableView.selectedRow
                if selectedRow >= 0 && selectedRow < monitoredRepositories.count {
                    selectedRepository = monitoredRepositories[selectedRow]
                    monitoredRemoveButton.isEnabled = true
                    updateWorkflowTableState()
                    loadWorkflowsForSelectedRepository()
                } else {
                    selectedRepository = nil
                    monitoredRemoveButton.isEnabled = false
                    updateWorkflowTableState()
                    currentWorkflows = []
                    workflowTableView.reloadData()
                }
            }
        }
        updateTabButtonStates()
    }
}

// MARK: - NSTabViewDelegate

extension RepositorySettingsWindow: NSTabViewDelegate {
    
    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Update button states when tab changes
        updateTabButtonStates()
        
        // Load data for the newly selected tab if needed
        guard let identifier = tabViewItem?.identifier as? String else { return }
        
        StatusBarDebugger.shared.log(.menu, "Tab changed", context: ["tab": identifier])
        
        switch identifier {
        case "personal":
            if GitHubOAuthConfig.isConfigured && personalRepositories.isEmpty {
                loadPersonalRepositories()
            }
        case "organizations":
            StatusBarDebugger.shared.log(.menu, "🔄 Processing organizations tab switch", context: [
                "isConfigured": "\(GitHubOAuthConfig.isConfigured)",
                "userOrgsCount": "\(userOrganizations.count)",
                "userOrgsEmpty": "\(userOrganizations.isEmpty)",
                "popupItemCount": "\(organizationsPopUp.numberOfItems)"
            ])
            
            if GitHubOAuthConfig.isConfigured && userOrganizations.isEmpty {
                StatusBarDebugger.shared.log(.menu, "🚀 Calling loadUserOrganizations (userOrganizations is empty)")
                loadUserOrganizations()
            } else if GitHubOAuthConfig.isConfigured {
                StatusBarDebugger.shared.log(.menu, "🔍 userOrganizations not empty - checking popup state")
                // If we have organizations but popup is empty, repopulate it
                if !userOrganizations.isEmpty && organizationsPopUp.numberOfItems == 0 {
                    StatusBarDebugger.shared.log(.menu, "🔧 Repopulating empty popup with existing data")
                    organizationsPopUp.removeAllItems()
                    organizationsPopUp.addItem(withTitle: "Select organization...")
                    for org in userOrganizations {
                        organizationsPopUp.addItem(withTitle: org.login)
                    }
                    organizationsPopUp.isEnabled = true
                    StatusBarDebugger.shared.log(.menu, "✅ Popup repopulated", context: [
                        "finalItemCount": "\(organizationsPopUp.numberOfItems)",
                        "finalItems": organizationsPopUp.itemTitles
                    ])
                } else {
                    StatusBarDebugger.shared.log(.menu, "ℹ️ No repopulation needed", context: [
                        "userOrgsEmpty": "\(userOrganizations.isEmpty)",
                        "popupItemCount": "\(organizationsPopUp.numberOfItems)"
                    ])
                }
            } else {
                StatusBarDebugger.shared.log(.menu, "⚠️ GitHub not configured - skipping organizations load")
            }
        case "searchtest":
            // Nothing to load automatically for search tab
            break
        case "monitored":
            // Refresh monitored repositories to show latest state
            monitoredRepositories = repositoryManager.getMonitoredRepositories()
            monitoredTableView.reloadData()
        default:
            break
        }
    }
    
    // MARK: - Testing Support Methods
    
    #if DEBUG
    /// Sets test data for monitored repositories (not API-related)
    /// This is needed because monitored repos come from RepositoryManager, not API calls
    public func setTestMonitoredRepositories(_ repositories: [MonitoredRepository]) {
        monitoredRepositories = repositories
        monitoredTableView.reloadData()
    }
    
    /// Sets test data for search results by configuring mock API response
    public func setTestSearchResults(_ repositories: [Repository]) {
        searchResults = repositories
        searchResultsTable.reloadData()
    }
    
    /// Sets test data for organizations (not API-related)
    /// This populates the organizations dropdown and enables API-like behavior
    public func setTestOrganizations(_ organizations: [Organization]) {
        userOrganizations = organizations
        organizationsPopUp.removeAllItems()
        
        if organizations.isEmpty {
            organizationsPopUp.addItem(withTitle: "No organizations")
            organizationsPopUp.isEnabled = false
        } else if organizations.count == 1 {
            // Auto-select single organization for better UX
            let singleOrg = organizations[0]
            organizationsPopUp.addItem(withTitle: singleOrg.login)
            organizationsPopUp.selectItem(at: 0)
            // Automatically load org repositories for single org
            organizationChanged()
        } else {
            // Multiple organizations - user needs to select
            organizationsPopUp.addItem(withTitle: "Select organization...")
            for org in organizations {
                organizationsPopUp.addItem(withTitle: org.login)
            }
            organizationsPopUp.isEnabled = true
        }
    }
    
    /// Sets test data for organization repositories
    public func setTestOrganizationRepositories(_ repositories: [Repository]) {
        selectedOrgRepositories = repositories
        orgTableView.reloadData()
    }
    #endif
    
    // MARK: - Workflow Configuration
    
}