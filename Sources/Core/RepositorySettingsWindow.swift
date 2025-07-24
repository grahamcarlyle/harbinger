import Cocoa

public class RepositorySettingsWindow: NSWindowController {
    
    private let repositoryManager = RepositoryManager()
    private let gitHubClient = GitHubClient()
    private var monitoredRepositories: [MonitoredRepository] = []
    
    // Main UI Elements
    private var tabView: NSTabView!
    private var refreshButton: NSButton!
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
    
    // Common elements across tabs
    private var tabAddButtons: [NSButton] = []
    private var monitoredRemoveButton: NSButton!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.minSize = NSSize(width: 800, height: 600)
        
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
        closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        
        buttonStack.addArrangedSubview(NSView()) // Spacer
        buttonStack.addArrangedSubview(refreshButton)
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
        nameColumn.width = 400
        nameColumn.minWidth = 200
        nameColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(nameColumn)
        
        let visibilityColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("visibility"))
        visibilityColumn.title = "Visibility"
        visibilityColumn.width = 100
        visibilityColumn.minWidth = 80
        visibilityColumn.resizingMask = .autoresizingMask
        personalTableView.addTableColumn(visibilityColumn)
        
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
        
        // Add scroll view directly to tab content with explicit constraints instead of stack view
        tabContent.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            scrollView.heightAnchor.constraint(equalToConstant: 400)
        ])
        
        // Force the table to size its columns to fill available width
        personalTableView.sizeLastColumnToFit()
        
        // Add button
        let addButton = NSButton(title: "Add Selected Repository", target: self, action: #selector(addPersonalRepository))
        addButton.isEnabled = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            addButton.centerXAnchor.constraint(equalTo: tabContent.centerXAnchor),
            addButton.bottomAnchor.constraint(lessThanOrEqualTo: tabContent.bottomAnchor, constant: -16)
        ])
        
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
        nameColumn.width = 400
        nameColumn.minWidth = 200
        nameColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(nameColumn)
        
        let visibilityColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("visibility"))
        visibilityColumn.title = "Visibility"
        visibilityColumn.width = 100
        visibilityColumn.minWidth = 80
        visibilityColumn.resizingMask = .autoresizingMask
        orgTableView.addTableColumn(visibilityColumn)
        
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
            scrollView.heightAnchor.constraint(equalToConstant: 400),
            
            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            addButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(lessThanOrEqualTo: tabContent.bottomAnchor, constant: -16)
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
            scrollView.heightAnchor.constraint(equalToConstant: 400),
            
            // Button positioning (depends on scroll view)  
            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            addButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            addButton.bottomAnchor.constraint(lessThanOrEqualTo: tabContent.bottomAnchor, constant: -16)
        ])
        
        // ROBUST FIX: Add explicit tab content constraints to prevent NSTabView sizing issues
        tabItem.view = tabContent
        tabView.addTabViewItem(tabItem)
        
        // After adding to tab view, constrain the content view to maintain proper size
        DispatchQueue.main.async { [weak self] in
            if let _ = self?.tabView.window {
                tabContent.widthAnchor.constraint(greaterThanOrEqualToConstant: 950).isActive = true
                tabContent.heightAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true
            }
        }
    }
    
    private func setupMonitoredRepositoriesTab() {
        let tabItem = NSTabViewItem(identifier: "monitored")
        tabItem.label = "Monitored"
        
        let tabContent = NSView()
        // ROBUST FIX: Force explicit content view sizing to prevent NSTabView layout bugs
        tabContent.frame = NSRect(x: 0, y: 0, width: 1000, height: 600)
        tabContent.autoresizingMask = [.width, .height]
        // Use constraints instead of autoresizing mask for more predictable behavior
        tabContent.translatesAutoresizingMaskIntoConstraints = false
        
        // Use stack view approach like the working Personal tab
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(mainStack)
        
        // Info label
        let infoLabel = NSTextField(labelWithString: "Repositories currently being monitored for workflow status")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(infoLabel)
        
        // Monitored repositories table
        monitoredTableView = NSTableView()
        monitoredTableView.rowSizeStyle = .default
        monitoredTableView.selectionHighlightStyle = .regular
        monitoredTableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        monitoredTableView.usesAlternatingRowBackgroundColors = true
        monitoredTableView.allowsColumnReordering = false
        monitoredTableView.allowsColumnResizing = true
        
        // Add columns with better width distribution
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Repository"
        nameColumn.width = 350
        nameColumn.minWidth = 200
        nameColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(nameColumn)
        
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
        
        let addedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("added"))
        addedColumn.title = "Added"
        addedColumn.width = 120
        addedColumn.minWidth = 100
        addedColumn.resizingMask = .autoresizingMask
        monitoredTableView.addTableColumn(addedColumn)
        
        let scrollView = NSScrollView()
        scrollView.documentView = monitoredTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add scroll view directly to tab content with explicit constraints instead of stack view
        tabContent.addSubview(scrollView)
        
        // Force the table to size its columns to fill available width
        monitoredTableView.sizeLastColumnToFit()
        
        // Remove button - use dedicated instance property to prevent external conflicts
        monitoredRemoveButton = NSButton(title: "Remove Selected Repository", target: self, action: #selector(removeRepository))
        monitoredRemoveButton.isEnabled = false
        monitoredRemoveButton.translatesAutoresizingMaskIntoConstraints = false
        tabContent.addSubview(monitoredRemoveButton)
        
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
            scrollView.heightAnchor.constraint(equalToConstant: 400),
            
            // Button positioning (depends on scroll view)
            monitoredRemoveButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            monitoredRemoveButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            monitoredRemoveButton.bottomAnchor.constraint(lessThanOrEqualTo: tabContent.bottomAnchor, constant: -16)
        ])
        
        // ROBUST FIX: Add explicit tab content constraints to prevent NSTabView sizing issues
        tabItem.view = tabContent
        tabView.addTabViewItem(tabItem)
        
        // After adding to tab view, constrain the content view to maintain proper size
        DispatchQueue.main.async { [weak self] in
            if let _ = self?.tabView.window {
                tabContent.widthAnchor.constraint(greaterThanOrEqualToConstant: 950).isActive = true
                tabContent.heightAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true
            }
        }
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
                    
                case .failure(let error):
                    self?.showError("Failed to fetch personal repositories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadUserOrganizations() {
        gitHubClient.getUserOrganizations { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let organizations):
                    self?.userOrganizations = organizations
                    self?.organizationsPopUp.removeAllItems()
                    
                    if organizations.isEmpty {
                        self?.organizationsPopUp.addItem(withTitle: "No organizations")
                        self?.organizationsPopUp.isEnabled = false
                    } else {
                        self?.organizationsPopUp.addItem(withTitle: "Select organization...")
                        for org in organizations {
                            self?.organizationsPopUp.addItem(withTitle: org.login)
                        }
                        self?.organizationsPopUp.isEnabled = true
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
        showLoading(true)
        
        gitHubClient.getOrganizationRepositories(org: orgLogin) { [weak self] result in
            DispatchQueue.main.async {
                self?.showLoading(false)
                
                switch result {
                case .success(let repositories):
                    self?.selectedOrgRepositories = repositories
                    self?.orgTableView.reloadData()
                    
                case .failure(let error):
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
        guard selectedIndex > 0, selectedIndex <= userOrganizations.count else {
            selectedOrgRepositories = []
            orgTableView.reloadData()
            return
        }
        
        let selectedOrg = userOrganizations[selectedIndex - 1]
        loadOrganizationRepositories(for: selectedOrg.login)
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
            
            // Clear selection and update button state
            monitoredTableView.deselectAll(nil)
            monitoredRemoveButton.isEnabled = false
            
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
            monitoredRemoveButton.isEnabled = monitoredTableView.selectedRow >= 0
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
        
        // Only trigger workflow detection for pending repositories (not for every cell render)
        if isPending {
            repository.checkWorkflowViability { [weak self] hasWorkflows in
                DispatchQueue.main.async {
                    // Reload the row to update appearance based on workflow detection
                    self?.reloadRepositoryRow(repository: repository)
                }
            }
        }
        
        switch identifier {
        case "name":
            var nameText = repository.fullName
            
            // Add loading indicator for pending repositories
            if isPending {
                nameText += " (checking workflows...)"
            }
            
            textField.stringValue = nameText
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            textField.textColor = baseTextColor
        case "visibility":
            var visibilityText = repository.private ? "Private" : "Public"
            
            // Add indicators for different states
            if isPending {
                visibilityText += " (Detecting...)"
            } else if !isViable {
                if repository.archived == true {
                    visibilityText += " (Archived)"
                } else if repository.disabled == true {
                    visibilityText += " (Disabled)"
                } else {
                    visibilityText += " (No workflows)"
                }
            }
            
            textField.stringValue = visibilityText
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
        case "language":
            textField.stringValue = repository.language ?? "—"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = secondaryTextColor
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
        
        // Only trigger workflow detection for pending repositories
        if isPending {
            repository.checkWorkflowViability { [weak self] hasWorkflows in
                DispatchQueue.main.async {
                    // Reload the row to update appearance based on workflow detection
                    self?.reloadRepositoryRow(repository: repository)
                }
            }
        }
        
        switch identifier {
        case "name":
            var nameText = repository.fullName
            
            // Add loading indicator for pending repositories
            if isPending {
                nameText += " (checking workflows...)"
            }
            
            textField.stringValue = nameText
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            textField.textColor = baseTextColor
        case "description":
            var descriptionText = repository.description ?? "No description"
            
            // Add indicators for different states
            if isPending {
                descriptionText = "[Detecting workflows] " + descriptionText
            } else if !isViable {
                if repository.archived == true {
                    descriptionText = "[Archived] " + descriptionText
                } else if repository.disabled == true {
                    descriptionText = "[Disabled] " + descriptionText
                } else {
                    descriptionText = "[No workflows] " + descriptionText
                }
            }
            
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
        default:
            break
        }
    }
    
    private func configureMonitoredCell(textField: NSTextField, repository: MonitoredRepository, identifier: String) {
        switch identifier {
        case "name":
            textField.stringValue = repository.fullName
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        case "type":
            textField.stringValue = repository.isPrivate ? "Private" : "Public"
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
        case "status":
            textField.stringValue = "Monitoring" // Placeholder - could show actual status
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .systemGreen
        case "added":
            textField.stringValue = "Recently" // Placeholder - could show actual date
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
        default:
            break
        }
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
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
            if GitHubOAuthConfig.isConfigured && userOrganizations.isEmpty {
                loadUserOrganizations()
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
    public func setTestData(monitoredRepositories: [MonitoredRepository]? = nil, searchResults: [Repository]? = nil) {
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            if let monitored = monitoredRepositories {
                self?.monitoredRepositories = monitored
                self?.monitoredTableView.reloadData()
                print("🧪 Test: Set monitored repositories to \(monitored.count) items")
                print("🔍 Test: monitoredTableView.numberOfRows after reload = \(self?.monitoredTableView.numberOfRows ?? -1)")
            }
            
            if let search = searchResults {
                self?.searchResults = search
                self?.searchResultsTable.reloadData()
                print("🧪 Test: Set search results to \(search.count) items")
                print("🔍 Test: searchResultsTable.numberOfRows after reload = \(self?.searchResultsTable.numberOfRows ?? -1)")
            }
            
            // Force layout update after data changes
            self?.window?.contentView?.layoutSubtreeIfNeeded()
        }
    }
    #endif
}