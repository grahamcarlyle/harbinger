import Cocoa

class StatusBarManager {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    // Status states
    enum WorkflowStatus {
        case unknown
        case passing
        case failing
        case running
    }
    
    private var currentStatus: WorkflowStatus = .unknown
    
    init() {
        print("🔧 StatusBarManager: Starting initialization")
        setupStatusBar()
        setupMenu()
        print("✅ StatusBarManager: Initialization complete")
    }
    
    private func setupStatusBar() {
        print("🔧 StatusBarManager: Setting up status bar")
        
        // Try different approaches to create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        print("🔧 StatusBarManager: Status item created: \(statusItem != nil ? "✅" : "❌")")
        
        guard let statusItem = statusItem else {
            print("❌ Failed to create status item")
            return
        }
        
        // Set up the button
        if let button = statusItem.button {
            print("🔧 StatusBarManager: Setting up button")
            button.title = "🔴 H"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Force visibility
            button.isHidden = false
            button.alphaValue = 1.0
            
            print("🔧 StatusBarManager: Button setup complete")
            print("🔧 StatusBarManager: Button title: '\(button.title)'")
            print("🔧 StatusBarManager: Button hidden: \(button.isHidden)")
            print("🔧 StatusBarManager: Button alpha: \(button.alphaValue)")
        } else {
            print("❌ Failed to get status item button")
        }
        
        // Force the status item to be visible
        statusItem.isVisible = true
        statusItem.length = NSStatusItem.variableLength
        
        print("🔧 StatusBarManager: Status item visible: \(statusItem.isVisible)")
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Add menu items
        let connectItem = NSMenuItem(title: "Connect to GitHub", action: #selector(connectToGitHub), keyEquivalent: "")
        connectItem.target = self
        menu?.addItem(connectItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu?.addItem(refreshItem)
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Harbinger", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
        
        statusItem?.menu = menu
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
        // This method is called when the status bar button is clicked
        // Menu will be shown automatically
    }
    
    @objc private func connectToGitHub() {
        print("Connect to GitHub clicked")
        
        // Create auth manager
        let authManager = AuthManager()
        
        // Step 1: Initiate device flow
        authManager.initiateDeviceFlow { [weak self] result in
            switch result {
            case .success(let (userCode, verificationURI)):
                print("✅ Device flow initiated")
                self?.showDeviceCodeDialog(userCode: userCode, verificationURI: verificationURI, authManager: authManager)
                
            case .failure(let error):
                print("❌ Device flow failed: \(error.localizedDescription)")
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
            
        case .alertSecondButtonReturn: // I've Done This
            // Start polling immediately
            startTokenPolling(authManager: authManager)
            
        case .alertThirdButtonReturn: // Cancel
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
            case .success(let accessToken):
                print("✅ Authentication successful!")
                self?.updateStatusIcon(.passing)
                self?.showSuccessDialog()
                
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
        // TODO: Implement workflow refresh
        print("Refresh clicked")
        
        // For now, cycle through states for testing
        let nextStatus: WorkflowStatus
        switch currentStatus {
        case .unknown:
            nextStatus = .passing
        case .passing:
            nextStatus = .failing
        case .failing:
            nextStatus = .running
        case .running:
            nextStatus = .unknown
        }
        
        updateStatusIcon(nextStatus)
    }
    
    @objc private func openSettings() {
        // TODO: Implement settings window
        print("Settings clicked")
    }
    
    @objc private func quit() {
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
    
    // Public accessor for debugging
    var debugStatusItem: NSStatusItem? {
        return statusItem
    }
}