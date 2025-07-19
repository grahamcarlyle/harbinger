import Cocoa

public class RepositorySettingsWindow: NSWindowController {
    
    private let repositoryManager = RepositoryManager()
    private var availableRepositories: [Repository] = []
    private var monitoredRepositories: [MonitoredRepository] = []
    
    // UI Elements
    private var availableTableView: NSTableView!
    private var monitoredTableView: NSTableView!
    private var addButton: NSButton!
    private var removeButton: NSButton!
    private var refreshButton: NSButton!
    private var closeButton: NSButton!
    private var loadingIndicator: NSProgressIndicator!
    
    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
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
        
        // Content stack
        let contentStack = NSStackView()
        contentStack.orientation = .horizontal
        contentStack.spacing = 16
        contentStack.distribution = .fillEqually
        mainStack.addArrangedSubview(contentStack)
        
        // Available repositories section
        let availableSection = createRepositorySection(
            title: "Available Repositories",
            tableView: &availableTableView
        )
        contentStack.addArrangedSubview(availableSection)
        
        // Control buttons section
        let controlSection = createControlSection()
        contentStack.addArrangedSubview(controlSection)
        
        // Monitored repositories section
        let monitoredSection = createRepositorySection(
            title: "Monitored Repositories",
            tableView: &monitoredTableView
        )
        contentStack.addArrangedSubview(monitoredSection)
        
        // Bottom buttons
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        
        refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshRepositories))
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
        availableTableView.delegate = self
        availableTableView.dataSource = self
        monitoredTableView.delegate = self
        monitoredTableView.dataSource = self
    }
    
    private func createRepositorySection(title: String, tableView: inout NSTableView!) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.spacing = 8
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        section.addArrangedSubview(titleLabel)
        
        // Table view in scroll view
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowSizeStyle = .default
        tableView.selectionHighlightStyle = .regular
        
        // Add columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Repository"
        nameColumn.width = 200
        tableView.addTableColumn(nameColumn)
        
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 80
        tableView.addTableColumn(typeColumn)
        
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        
        section.addArrangedSubview(scrollView)
        
        return section
    }
    
    private func createControlSection() -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.spacing = 12
        section.alignment = .centerX
        
        // Add spacer
        section.addArrangedSubview(NSView())
        
        // Add button
        addButton = NSButton(title: "→ Add →", target: self, action: #selector(addRepository))
        addButton.isEnabled = false
        section.addArrangedSubview(addButton)
        
        // Remove button
        removeButton = NSButton(title: "← Remove ←", target: self, action: #selector(removeRepository))
        removeButton.isEnabled = false
        section.addArrangedSubview(removeButton)
        
        // Add spacer
        section.addArrangedSubview(NSView())
        
        return section
    }
    
    private func loadData() {
        // Load monitored repositories
        monitoredRepositories = repositoryManager.getMonitoredRepositories()
        monitoredTableView.reloadData()
        
        // Load available repositories if authenticated
        if GitHubOAuthConfig.isConfigured {
            fetchAvailableRepositories()
        } else {
            showAuthenticationRequiredMessage()
        }
    }
    
    private func fetchAvailableRepositories() {
        showLoading(true)
        
        repositoryManager.fetchAvailableRepositories { [weak self] (result: Result<[Repository], GitHubClient.GitHubError>) in
            DispatchQueue.main.async {
                self?.showLoading(false)
                
                switch result {
                case .success(let repositories):
                    self?.availableRepositories = repositories
                    self?.availableTableView.reloadData()
                    
                case .failure(let error):
                    self?.showError("Failed to fetch repositories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showLoading(_ show: Bool) {
        loadingIndicator.isHidden = !show
        if show {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
        refreshButton.isEnabled = !show
    }
    
    private func showAuthenticationRequiredMessage() {
        let alert = NSAlert()
        alert.messageText = "Authentication Required"
        alert.informativeText = "Please connect to GitHub from the status bar menu to manage repositories."
        alert.addButton(withTitle: "OK")
        if let window = window {
            alert.beginSheetModal(for: window)
        }
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
    
    // MARK: - Actions
    
    @objc private func addRepository() {
        let selectedRow = availableTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < availableRepositories.count else { return }
        
        let repository = availableRepositories[selectedRow]
        let monitoredRepo = MonitoredRepository(from: repository)
        
        if repositoryManager.addRepository(monitoredRepo) {
            monitoredRepositories = repositoryManager.getMonitoredRepositories()
            monitoredTableView.reloadData()
            
            // Clear selection and update button state
            availableTableView.deselectAll(nil)
            updateButtonStates()
        }
    }
    
    @objc private func removeRepository() {
        let selectedRow = monitoredTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < monitoredRepositories.count else { return }
        
        let repository = monitoredRepositories[selectedRow]
        
        if repositoryManager.removeRepository(repository) {
            monitoredRepositories = repositoryManager.getMonitoredRepositories()
            monitoredTableView.reloadData()
            
            // Clear selection and update button state
            monitoredTableView.deselectAll(nil)
            updateButtonStates()
        }
    }
    
    @objc private func refreshRepositories() {
        fetchAvailableRepositories()
    }
    
    @objc private func closeWindow() {
        window?.close()
    }
    
    private func updateButtonStates() {
        addButton.isEnabled = availableTableView.selectedRow >= 0
        removeButton.isEnabled = monitoredTableView.selectedRow >= 0
    }
}

// MARK: - Table View Data Source & Delegate

extension RepositorySettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == availableTableView {
            return availableRepositories.count
        } else if tableView == monitoredTableView {
            return monitoredRepositories.count
        }
        return 0
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        if tableView == availableTableView {
            guard row < availableRepositories.count else { return nil }
            let repository = availableRepositories[row]
            
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            if identifier.rawValue == "name" {
                textField.stringValue = repository.fullName
            } else if identifier.rawValue == "type" {
                textField.stringValue = repository.private ? "Private" : "Public"
            }
            
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        } else if tableView == monitoredTableView {
            guard row < monitoredRepositories.count else { return nil }
            let repository = monitoredRepositories[row]
            
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            if identifier.rawValue == "name" {
                textField.stringValue = repository.fullName
            } else if identifier.rawValue == "type" {
                textField.stringValue = repository.isPrivate ? "Private" : "Public"
            }
            
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
        }
        
        return nil
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }
}