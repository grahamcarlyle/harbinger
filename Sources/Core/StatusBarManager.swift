import Cocoa

public class StatusBarManager {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let workflowMonitor = WorkflowMonitor()
    
    // Debugging components
    private let debugger = StatusBarDebugger.shared
    private var stateVerifier: StatusBarStateVerifier?
    private var selfHealer: StatusBarSelfHealer?
    private var lastKnownGoodState: Date?
    
    // Status states
    enum WorkflowStatus {
        case unknown
        case passing
        case failing
        case running
    }
    
    private var currentStatus: WorkflowStatus = .unknown
    private var repositoryStatuses: [RepositoryWorkflowStatus] = []
    private var hasErrors: Bool = false
    
    public init() {
        debugger.log(.lifecycle, "StatusBarManager initialization started")
        
        do {
            try setupStatusBar()
            setupMenu()
            setupWorkflowMonitor()
            setupDebugging()
            
            lastKnownGoodState = Date()
            debugger.log(.lifecycle, "StatusBarManager initialization completed successfully")
        } catch {
            debugger.log(.error, "StatusBarManager initialization failed", context: ["error": error.localizedDescription])
            hasErrors = true
        }
    }
    
    private func setupDebugging() {
        stateVerifier = StatusBarStateVerifier(statusItem: statusItem, menu: menu)
        selfHealer = StatusBarSelfHealer(statusBarManager: self)
        
        // Perform initial health check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.performHealthCheck()
        }
        
        debugger.log(.lifecycle, "Debugging system initialized")
    }
    
    private func setupWorkflowMonitor() {
        debugger.log(.lifecycle, "Setting up workflow monitor")
        
        workflowMonitor.delegate = self
        
        // Start monitoring if we have repositories and authentication
        if GitHubOAuthConfig.isConfigured {
            debugger.log(.lifecycle, "Authentication detected, starting workflow monitoring")
            workflowMonitor.startMonitoring()
        } else {
            debugger.log(.lifecycle, "No authentication, workflow monitoring will start after login")
        }
    }
    
    private func setupStatusBar() throws {
        debugger.log(.lifecycle, "Setting up status bar")
        
        // Try different approaches to create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        let statusItemExists = statusItem != nil
        debugger.log(.lifecycle, "Status item creation", context: ["success": statusItemExists])
        
        guard let statusItem = statusItem else {
            let error = NSError(domain: "StatusBarManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to create status item"])
            debugger.log(.error, "Failed to create status item")
            throw error
        }
        
        // Set up the button
        guard let button = statusItem.button else {
            let error = NSError(domain: "StatusBarManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to get status item button"])
            debugger.log(.error, "Failed to get status item button")
            throw error
        }
        
        debugger.log(.lifecycle, "Setting up button properties")
        
        // Configure button with defensive checks
        button.title = "🔴 H"
        button.action = #selector(statusBarButtonClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Force visibility with validation
        button.isHidden = false
        button.alphaValue = 1.0
        
        // Validate button setup
        let buttonContext: [String: Any] = [
            "title": button.title,
            "hasAction": button.action != nil,
            "hasTarget": button.target != nil,
            "isHidden": button.isHidden,
            "alphaValue": button.alphaValue
        ]
        
        debugger.log(.lifecycle, "Button setup completed", context: buttonContext)
        
        // Force the status item to be visible with validation
        statusItem.isVisible = true
        statusItem.length = NSStatusItem.variableLength
        
        let statusItemContext: [String: Any] = [
            "isVisible": statusItem.isVisible,
            "length": statusItem.length
        ]
        
        debugger.log(.lifecycle, "Status item configuration completed", context: statusItemContext)
        
        // Verify the setup worked
        if !statusItem.isVisible {
            debugger.log(.warning, "Status item reports as not visible after setup")
        }
        
        if button.isHidden {
            debugger.log(.warning, "Button reports as hidden after setup")
        }
    }
    
    private func setupMenu() {
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        debugger.log(.menu, "Rebuilding menu")
        
        guard statusItem != nil else {
            debugger.log(.error, "Cannot rebuild menu: statusItem is nil")
            hasErrors = true
            return
        }
        
        menu = NSMenu()
        
        // Add error indicator if there are issues
        if hasErrors {
            let errorItem = NSMenuItem(title: "⚠️ Debug Issues Detected", action: #selector(showDebugInfo), keyEquivalent: "")
            errorItem.target = self
            menu?.addItem(errorItem)
            menu?.addItem(NSMenuItem.separator())
        }
        
        let isAuthenticated = GitHubOAuthConfig.isConfigured
        debugger.log(.menu, "Building menu", context: ["authenticated": isAuthenticated, "repositories": repositoryStatuses.count])
        
        // Authentication status
        if isAuthenticated {
            // Repository statuses section
            if !repositoryStatuses.isEmpty {
                let statusHeader = NSMenuItem(title: "Repository Status", action: nil, keyEquivalent: "")
                statusHeader.isEnabled = false
                menu?.addItem(statusHeader)
                
                for repoStatus in repositoryStatuses {
                    addRepositoryStatusToMenu(repoStatus)
                }
                
                menu?.addItem(NSMenuItem.separator())
            } else {
                let noReposItem = NSMenuItem(title: "No repositories monitored", action: nil, keyEquivalent: "")
                noReposItem.isEnabled = false
                menu?.addItem(noReposItem)
                menu?.addItem(NSMenuItem.separator())
            }
        } else {
            let connectItem = createMenuItem(title: "Connect to GitHub", action: #selector(connectToGitHub))
            menu?.addItem(connectItem)
            menu?.addItem(NSMenuItem.separator())
        }
        
        // Control items
        let refreshItem = createMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        menu?.addItem(refreshItem)
        
        let settingsItem = createMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        menu?.addItem(settingsItem)
        
        if isAuthenticated {
            let disconnectItem = createMenuItem(title: "Disconnect from GitHub", action: #selector(disconnectFromGitHub))
            menu?.addItem(disconnectItem)
        }
        
        menu?.addItem(NSMenuItem.separator())
        
        // Debug items (only show if there are issues or in debug mode)
        if hasErrors || ProcessInfo.processInfo.environment["HARBINGER_DEBUG"] == "1" {
            let debugItem = createMenuItem(title: "🔍 Show Debug Info", action: #selector(showDebugInfo))
            menu?.addItem(debugItem)
            
            let healthCheckItem = createMenuItem(title: "🩹 Run Health Check", action: #selector(runHealthCheck))
            menu?.addItem(healthCheckItem)
            
            menu?.addItem(NSMenuItem.separator())
        }
        
        let quitItem = createMenuItem(title: "Quit Harbinger", action: #selector(quit), keyEquivalent: "q")
        menu?.addItem(quitItem)
        
        // Assign menu to status item with validation
        statusItem?.menu = menu
        
        let menuItemCount = menu?.items.count ?? 0
        debugger.log(.menu, "Menu rebuild completed", context: ["itemCount": menuItemCount])
        
        // Update state verifier
        stateVerifier = StatusBarStateVerifier(statusItem: statusItem, menu: menu)
    }
    
    private func createMenuItem(title: String, action: Selector?, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        
        debugger.log(.menu, "Created menu item", context: ["title": title, "hasAction": action != nil])
        return item
    }
    
    private func addRepositoryStatusToMenu(_ repoStatus: RepositoryWorkflowStatus) {
        // Repository header
        let repoItem = NSMenuItem(title: "📁 \(repoStatus.repository.displayName)", action: nil, keyEquivalent: "")
        repoItem.isEnabled = false
        menu?.addItem(repoItem)
        
        // Overall status
        let statusItem = NSMenuItem(title: "   \(repoStatus.statusDescription)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu?.addItem(statusItem)
        
        // Recent workflows (show up to 3)
        let recentWorkflows = Array(repoStatus.workflows.prefix(3))
        for workflow in recentWorkflows {
            let workflowTitle = "   \(workflow.statusEmoji) \(workflow.name) (\(workflow.shortCommitSha))"
            let workflowItem = NSMenuItem(title: workflowTitle, action: #selector(openWorkflowURL(_:)), keyEquivalent: "")
            workflowItem.target = self
            workflowItem.representedObject = workflow.url
            menu?.addItem(workflowItem)
        }
        
        // Show "View on GitHub" option
        let viewItem = NSMenuItem(title: "   → View on GitHub", action: #selector(openRepositoryURL(_:)), keyEquivalent: "")
        viewItem.target = self
        viewItem.representedObject = repoStatus.repository.url
        menu?.addItem(viewItem)
    }
    
    private func updateStatusIcon(_ status: WorkflowStatus) {
        currentStatus = status
        
        guard let button = statusItem?.button else { return }
        
        // Create colored circle icons
        let image = createStatusIcon(for: status)
        button.image = image
        
        // Update tooltip
        button.toolTip = getTooltipText(for: status)
    }
    
    private func createStatusIcon(for status: WorkflowStatus) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw colored circle
        let rect = NSRect(x: 2, y: 2, width: 14, height: 14)
        let path = NSBezierPath(ovalIn: rect)
        
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
        
        color.setFill()
        path.fill()
        
        // Add border
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        image.unlockFocus()
        
        // Make template image for proper appearance in menu bar
        image.isTemplate = true
        
        return image
    }
    
    private func getTooltipText(for status: WorkflowStatus) -> String {
        switch status {
        case .unknown:
            return "Harbinger: Not connected"
        case .passing:
            return "Harbinger: All workflows passing"
        case .failing:
            return "Harbinger: Some workflows failing"
        case .running:
            return "Harbinger: Workflows running"
        }
    }
    
    // MARK: - Menu Actions
    
    @objc private func statusBarButtonClicked() {
        debugger.log(.menu, "Status bar button clicked")
        
        // Verify menu is properly attached
        if statusItem?.menu == nil {
            debugger.log(.error, "Status bar button clicked but no menu attached")
            hasErrors = true
            rebuildMenu()
        }
        
        // Menu will be shown automatically by NSStatusItem
    }
    
    @objc private func connectToGitHub() {
        debugger.log(.menu, "Connect to GitHub menu item clicked")
        
        // Create auth manager with error handling
        let authManager = AuthManager()
        
        debugger.log(.network, "Initiating OAuth device flow")
        
        // Step 1: Initiate device flow
        authManager.initiateDeviceFlow { [weak self] result in
            switch result {
            case .success(let (userCode, verificationURI)):
                self?.debugger.log(.network, "Device flow successful", context: ["userCode": userCode, "uri": verificationURI])
                self?.showDeviceCodeDialog(userCode: userCode, verificationURI: verificationURI, authManager: authManager)
                
            case .failure(let error):
                self?.debugger.log(.error, "Device flow failed", context: ["error": error.localizedDescription])
                self?.showErrorDialog(message: "Failed to start GitHub authentication: \(error.localizedDescription)")
            }
        }
    }
    
    private func showDeviceCodeDialog(userCode: String, verificationURI: String, authManager: AuthManager) {
        let alert = NSAlert()
        alert.messageText = "GitHub Authorization"
        alert.informativeText = """
        1. Go to: \(verificationURI)
        
        2. Enter this code: \(userCode)
        
        3. Click "Authorize" on the GitHub page
        
        This app will automatically detect when you've completed the authorization.
        """
        alert.addButton(withTitle: "Open GitHub")
        alert.addButton(withTitle: "Copy Code")
        alert.addButton(withTitle: "I've Done This")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Open GitHub
            if let url = URL(string: verificationURI) {
                NSWorkspace.shared.open(url)
            }
            // Start polling after opening browser
            startTokenPolling(authManager: authManager)
            
        case .alertSecondButtonReturn: // Copy Code
            // Copy the user code to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(userCode, forType: .string)
            
            print("📋 User code copied to clipboard: \(userCode)")
            
            // Show confirmation and re-show dialog
            let copyAlert = NSAlert()
            copyAlert.messageText = "Code Copied"
            copyAlert.informativeText = "The code '\(userCode)' has been copied to your clipboard. You can now paste it on the GitHub authorization page."
            copyAlert.addButton(withTitle: "OK")
            copyAlert.runModal()
            
            // Re-show the authorization dialog
            showDeviceCodeDialog(userCode: userCode, verificationURI: verificationURI, authManager: authManager)
            
        case .alertThirdButtonReturn: // I've Done This
            // Start polling immediately
            startTokenPolling(authManager: authManager)
            
        case NSApplication.ModalResponse(rawValue: 1003): // Cancel (fourth button)
            authManager.cancelAuthentication()
            print("🔧 StatusBarManager: Authentication canceled")
            
        default:
            break
        }
    }
    
    private func startTokenPolling(authManager: AuthManager) {
        print("🔧 StatusBarManager: Starting token polling...")
        
        // Show waiting state
        updateStatusIcon(.running)
        
        // Start polling for access token
        authManager.pollForAccessToken { [weak self] result in
            switch result {
            case .success(_):
                print("✅ Authentication successful!")
                self?.updateStatusIcon(.unknown)
                self?.showSuccessDialog()
                
                // Start monitoring after successful authentication
                self?.workflowMonitor.startMonitoring()
                self?.rebuildMenu()
                
            case .failure(let error):
                print("❌ Authentication failed: \(error.localizedDescription)")
                self?.updateStatusIcon(.unknown)
                self?.showErrorDialog(message: "Authentication failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func showSuccessDialog() {
        let alert = NSAlert()
        alert.messageText = "Authentication Successful"
        alert.informativeText = "Harbinger is now connected to your GitHub account!"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = "Authentication Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func refresh() {
        print("Refresh clicked")
        
        guard GitHubOAuthConfig.isConfigured else {
            print("❌ No OAuth token available")
            showErrorDialog(message: "Please connect to GitHub first")
            return
        }
        
        updateStatusIcon(.running)
        workflowMonitor.refreshAllRepositories()
    }
    
    @objc private func openWorkflowURL(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else {
            print("❌ Invalid workflow URL")
            return
        }
        
        print("🔗 Opening workflow URL: \(urlString)")
        NSWorkspace.shared.open(url)
    }
    
    @objc private func openRepositoryURL(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else {
            print("❌ Invalid repository URL")
            return
        }
        
        print("🔗 Opening repository URL: \(urlString)")
        NSWorkspace.shared.open(url)
    }
    
    @objc private func disconnectFromGitHub() {
        print("Disconnect from GitHub clicked")
        
        let alert = NSAlert()
        alert.messageText = "Disconnect from GitHub?"
        alert.informativeText = "This will remove your access token and stop monitoring workflows. You can reconnect anytime."
        alert.addButton(withTitle: "Disconnect")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Clear the stored token
            GitHubOAuthConfig.clearCredentials()
            
            // Stop monitoring
            workflowMonitor.stopMonitoring()
            
            // Reset status
            repositoryStatuses = []
            updateStatusIcon(.unknown)
            rebuildMenu()
            
            print("✅ Disconnected from GitHub")
        }
    }
    
    @objc private func openSettings() {
        print("Settings clicked")
        
        // Create and show repository settings window
        let settingsWindow = RepositorySettingsWindow()
        settingsWindow.showWindow(nil)
        
        // Bring window to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showDebugInfo() {
        debugger.log(.menu, "Show debug info menu item clicked")
        
        let report = debugger.generateDebugReport()
        
        let alert = NSAlert()
        alert.messageText = "Harbinger Debug Information"
        alert.informativeText = "Debug report has been copied to clipboard and printed to console."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy to Clipboard")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(report, forType: .string)
        }
        
        print(report)
    }
    
    @objc private func runHealthCheck() {
        debugger.log(.menu, "Run health check menu item clicked")
        
        guard let selfHealer = selfHealer else {
            debugger.log(.error, "Self healer not initialized")
            return
        }
        
        let success = selfHealer.performHealthCheck()
        
        let alert = NSAlert()
        alert.messageText = success ? "Health Check Passed" : "Health Check Failed"
        alert.informativeText = success ? "All systems are functioning normally." : "Issues were detected and healing was attempted. Check console for details."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quit() {
        debugger.log(.lifecycle, "Quit menu item clicked - shutting down")
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Public Methods
    
    func updateWorkflowStatus(_ status: WorkflowStatus) {
        DispatchQueue.main.async {
            self.updateStatusIcon(status)
        }
    }
    
    func isConnected() -> Bool {
        return GitHubOAuthConfig.isConfigured
    }
    
    // MARK: - Public Debugging Interface
    
    @discardableResult
    public func performHealthCheck() -> Bool {
        return selfHealer?.performHealthCheck() ?? false
    }
    
    public func generateDebugReport() -> String {
        return debugger.generateDebugReport()
    }
    
    public func logCurrentState() {
        stateVerifier?.logDetailedState()
    }
    
    public func verifyState() -> StatusBarStateVerifier.VerificationResult? {
        return stateVerifier?.verifyState()
    }
    
    // MARK: - Self-Healing Methods
    
    public func recreateStatusItem() {
        debugger.log(.healing, "Recreating status item")
        
        // Clean up existing status item
        if let existingItem = statusItem {
            NSStatusBar.system.removeStatusItem(existingItem)
            debugger.log(.healing, "Removed existing status item")
        }
        
        // Reset state
        statusItem = nil
        menu = nil
        hasErrors = false
        
        // Recreate everything
        do {
            try setupStatusBar()
            setupMenu()
            
            // Update state verifier
            stateVerifier = StatusBarStateVerifier(statusItem: statusItem, menu: menu)
            
            debugger.log(.healing, "Status item recreated successfully")
            lastKnownGoodState = Date()
            
        } catch {
            debugger.log(.error, "Failed to recreate status item", context: ["error": error.localizedDescription])
            hasErrors = true
        }
    }
    
    // Public accessor for debugging
    var debugStatusItem: NSStatusItem? {
        return statusItem
    }
    
    // MARK: - Environment Detection
    
    private var isDebugMode: Bool {
        return ProcessInfo.processInfo.environment["HARBINGER_DEBUG"] == "1" || hasErrors
    }
}

// MARK: - WorkflowMonitorDelegate

extension StatusBarManager: WorkflowMonitorDelegate {
    
    public func workflowMonitor(_ monitor: WorkflowMonitor, didUpdateOverallStatus status: WorkflowRunStatus, statusText: String) {
        debugger.log(.network, "Received overall status update", context: ["status": "\(status)", "text": statusText])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                StatusBarDebugger.shared.log(.error, "StatusBarManager deallocated during status update")
                return
            }
            
            // Convert WorkflowRunStatus to internal WorkflowStatus
            let internalStatus: WorkflowStatus
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
            
            self.updateStatusIcon(internalStatus)
            
            // Update tooltip with overall status
            if let button = self.statusItem?.button {
                button.toolTip = "Harbinger: \(statusText)"
                self.debugger.log(.state, "Updated tooltip", context: ["tooltip": button.toolTip ?? "nil"])
            } else {
                self.debugger.log(.warning, "Could not update tooltip - button is nil")
            }
            
            self.debugger.log(.state, "Overall status updated", context: ["status": "\(status)", "text": statusText])
        }
    }
    
    public func workflowMonitor(_ monitor: WorkflowMonitor, didUpdateRepository repositoryStatus: RepositoryWorkflowStatus) {
        debugger.log(.network, "Received repository status update", 
                   context: ["repository": repositoryStatus.repository.fullName, "status": repositoryStatus.statusDescription])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                StatusBarDebugger.shared.log(.error, "StatusBarManager deallocated during repository update")
                return
            }
            
            // Update the repository status in our cache
            let repoName = repositoryStatus.repository.fullName
            if let index = self.repositoryStatuses.firstIndex(where: { $0.repository.fullName == repoName }) {
                self.repositoryStatuses[index] = repositoryStatus
                self.debugger.log(.state, "Updated existing repository status", context: ["repository": repoName])
            } else {
                self.repositoryStatuses.append(repositoryStatus)
                self.debugger.log(.state, "Added new repository status", context: ["repository": repoName])
            }
            
            // Rebuild menu to show updated statuses
            self.rebuildMenu()
            
            self.debugger.log(.state, "Repository status processed", 
                            context: ["repository": repoName, "totalRepos": self.repositoryStatuses.count])
        }
    }
}