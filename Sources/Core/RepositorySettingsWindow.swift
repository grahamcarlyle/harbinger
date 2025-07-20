import Cocoa

public class RepositorySettingsWindow: NSWindowController {
    
    private let repositoryManager = RepositoryManager()
    private let gitHubClient = GitHubClient()
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
    
    // Manual repository entry
    private var repoEntryField: NSTextField!
    private var addManualButton: NSButton!
    private var repoSuggestions: [String] = []
    
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
        
        // Manual repository entry section
        let manualEntrySection = createManualEntrySection()
        mainStack.addArrangedSubview(manualEntrySection)
        
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
    
    private func createManualEntrySection() -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.spacing = 8
        
        // Section title
        let titleLabel = NSTextField(labelWithString: "Add Repository Manually")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.alignment = .left
        section.addArrangedSubview(titleLabel)
        
        // Instructions
        let instructionLabel = NSTextField(labelWithString: "Enter repository in format: owner/repo (e.g., microsoft/vscode)")
        instructionLabel.font = NSFont.systemFont(ofSize: 11)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.alignment = .left
        section.addArrangedSubview(instructionLabel)
        
        // Entry row
        let entryRow = NSStackView()
        entryRow.orientation = .horizontal
        entryRow.spacing = 8
        
        // Text field with autocomplete
        repoEntryField = NSTextField()
        repoEntryField.placeholderString = "owner/repository"
        repoEntryField.delegate = self
        repoEntryField.target = self
        repoEntryField.action = #selector(repoFieldChanged)
        
        // Add button
        addManualButton = NSButton(title: "Add Repository", target: self, action: #selector(addManualRepository))
        addManualButton.isEnabled = false
        
        entryRow.addArrangedSubview(repoEntryField)
        entryRow.addArrangedSubview(addManualButton)
        
        // Set constraints for better layout
        repoEntryField.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        addManualButton.widthAnchor.constraint(equalToConstant: 120).isActive = true
        
        section.addArrangedSubview(entryRow)
        
        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        section.addArrangedSubview(separator)
        
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
        // Load monitored repositories (always available without authentication)
        monitoredRepositories = repositoryManager.getMonitoredRepositories()
        monitoredTableView.reloadData()
        
        // Load available repositories if authenticated
        if GitHubOAuthConfig.isConfigured {
            fetchAvailableRepositories()
        } else {
            // Show empty available repositories (user can still manage monitored ones)
            availableRepositories = []
            availableTableView.reloadData()
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
    
    // MARK: - Actions
    
    @objc private func repoFieldChanged() {
        let text = repoEntryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        addManualButton.isEnabled = isValidRepositoryFormat(text)
        
        // Update autocomplete suggestions
        updateAutocompleteSuggestions(for: text)
    }
    
    @objc private func addManualRepository() {
        let repoText = repoEntryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidRepositoryFormat(repoText) else {
            showError("Please enter a valid repository format: owner/repo")
            return
        }
        
        // Parse owner and repo name
        let parts = repoText.split(separator: "/")
        let owner = String(parts[0])
        let repo = String(parts[1])
        
        StatusBarDebugger.shared.log(.menu, "Adding manual repository", context: ["repo": repoText])
        
        // Check if repository is already monitored
        if monitoredRepositories.contains(where: { $0.fullName.lowercased() == repoText.lowercased() }) {
            showError("Repository '\(repoText)' is already being monitored")
            return
        }
        
        // Try to fetch repository info from GitHub first to validate it exists
        validateAndAddRepository(owner: owner, repo: repo, fullName: repoText)
    }
    
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
        StatusBarDebugger.shared.log(.menu, "Repository settings refresh clicked")
        
        if GitHubOAuthConfig.isConfigured {
            fetchAvailableRepositories()
        } else {
            // Show a helpful message instead of trying to fetch
            let alert = NSAlert()
            alert.messageText = "GitHub Authentication Required"
            alert.informativeText = "To see available repositories, please connect to GitHub from the status bar menu first."
            alert.addButton(withTitle: "OK")
            if let window = window {
                alert.beginSheetModal(for: window)
            }
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
    
    private func updateButtonStates() {
        addButton.isEnabled = availableTableView.selectedRow >= 0
        removeButton.isEnabled = monitoredTableView.selectedRow >= 0
    }
    
    // MARK: - Manual Repository Entry Helpers
    
    private func isValidRepositoryFormat(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/")
        
        // Must have exactly 2 parts (owner/repo)
        guard parts.count == 2 else { return false }
        
        // Both parts must be non-empty and contain valid characters
        let owner = String(parts[0])
        let repo = String(parts[1])
        
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        
        return !owner.isEmpty && 
               !repo.isEmpty && 
               owner.rangeOfCharacter(from: validCharacterSet.inverted) == nil &&
               repo.rangeOfCharacter(from: validCharacterSet.inverted) == nil
    }
    
    private func updateAutocompleteSuggestions(for text: String) {
        // Create suggestions from available repositories and monitored repositories
        var suggestions: [String] = []
        
        // Add from available repositories
        for repo in availableRepositories {
            if repo.fullName.lowercased().hasPrefix(text.lowercased()) {
                suggestions.append(repo.fullName)
            }
        }
        
        // Add from monitored repositories (for reference)
        for repo in monitoredRepositories {
            if repo.fullName.lowercased().hasPrefix(text.lowercased()) && !suggestions.contains(repo.fullName) {
                suggestions.append(repo.fullName + " (already monitored)")
            }
        }
        
        // Add some common repository patterns if the user is typing owner/
        if text.contains("/") && text.split(separator: "/").count == 2 {
            let parts = text.split(separator: "/")
            let owner = String(parts[0])
            let partialRepo = String(parts[1])
            
            if !partialRepo.isEmpty {
                // Common repository name patterns
                let commonPatterns = ["backend", "frontend", "api", "web", "app", "mobile", "desktop", "cli", "docs", "website"]
                for pattern in commonPatterns {
                    if pattern.hasPrefix(partialRepo.lowercased()) {
                        let suggestion = "\(owner)/\(pattern)"
                        if !suggestions.contains(suggestion) {
                            suggestions.append(suggestion)
                        }
                    }
                }
            }
        }
        
        repoSuggestions = Array(suggestions.prefix(10)) // Limit to 10 suggestions
        
        // Update the text field's completion
        repoEntryField.stringValue = text
    }
    
    private func validateAndAddRepository(owner: String, repo: String, fullName: String) {
        // Show loading state
        addManualButton.isEnabled = false
        addManualButton.title = "Validating..."
        
        // Use retained GitHub client to validate the repository
        gitHubClient.getRepository(owner: owner, repo: repo) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.addManualButton.title = "Add Repository"
                
                switch result {
                case .success(let repository):
                    // Repository exists, create monitored repository and add it
                    let monitoredRepo = MonitoredRepository(from: repository)
                    
                    if self.repositoryManager.addRepository(monitoredRepo) {
                        self.monitoredRepositories = self.repositoryManager.getMonitoredRepositories()
                        self.monitoredTableView.reloadData()
                        
                        // Clear the text field
                        self.repoEntryField.stringValue = ""
                        self.addManualButton.isEnabled = false
                        
                        StatusBarDebugger.shared.log(.menu, "Successfully added manual repository", context: ["repo": fullName])
                        
                        // Show success message
                        let alert = NSAlert()
                        alert.messageText = "Repository Added"
                        alert.informativeText = "Successfully added '\(fullName)' to monitoring list"
                        alert.addButton(withTitle: "OK")
                        if let window = self.window {
                            alert.beginSheetModal(for: window)
                        }
                    } else {
                        self.showError("Failed to add repository to monitoring list")
                    }
                    
                case .failure(let error):
                    StatusBarDebugger.shared.log(.error, "Failed to validate repository", context: ["repo": fullName, "error": error.localizedDescription])
                    
                    // Check if it's a not found error or access denied
                    switch error {
                    case .notFound:
                        self.showError("Repository '\(fullName)' not found. Please check the owner and repository name.")
                    case .rateLimitExceeded:
                        self.showError("GitHub rate limit exceeded. Please try again later.")
                    case .unauthorized:
                        self.showError("Access denied. The repository may be private and require authentication.")
                    default:
                        self.showError("Failed to validate repository: \(error.localizedDescription)")
                    }
                    
                    self.addManualButton.isEnabled = self.isValidRepositoryFormat(self.repoEntryField.stringValue)
                }
            }
        }
    }
}

// MARK: - NSTextFieldDelegate

extension RepositorySettingsWindow: NSTextFieldDelegate {
    
    public func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField, textField == repoEntryField {
            repoFieldChanged()
        }
    }
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle Enter key to trigger add action
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if addManualButton.isEnabled {
                addManualRepository()
                return true
            }
        }
        return false
    }
}

// MARK: - Table View Data Source & Delegate

extension RepositorySettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == availableTableView {
            // Show at least one row for info message if not authenticated and no repositories
            if availableRepositories.isEmpty && !GitHubOAuthConfig.isConfigured {
                return 1
            }
            return availableRepositories.count
        } else if tableView == monitoredTableView {
            return monitoredRepositories.count
        }
        return 0
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        if tableView == availableTableView {
            // Show info message if not authenticated and no repositories
            if availableRepositories.isEmpty && !GitHubOAuthConfig.isConfigured && row == 0 {
                let cellView = NSTableCellView()
                let textField = NSTextField()
                textField.isBordered = false
                textField.isEditable = false
                textField.backgroundColor = .clear
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.textColor = .secondaryLabelColor
                textField.font = NSFont.systemFont(ofSize: 12)
                
                if identifier.rawValue == "name" {
                    textField.stringValue = "Connect to GitHub to see repositories"
                } else if identifier.rawValue == "type" {
                    textField.stringValue = "—"
                }
                
                cellView.addSubview(textField)
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
                ])
                
                return cellView
            }
            
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