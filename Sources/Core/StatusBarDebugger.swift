import Cocoa
import Foundation

// MARK: - Debug Logger

public class StatusBarDebugger {
    
    public static let shared = StatusBarDebugger()
    
    private var debugLog: [DebugEntry] = []
    private let maxLogEntries = 1000
    private let logFileURL: URL
    
    private init() {
        // Create logs directory in user's Documents folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("HarbingerLogs")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        // Create log file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        logFileURL = logsDirectory.appendingPathComponent("harbinger_\(timestamp).log")
        
        // Write initial header
        writeToLogFile("=== HARBINGER DEBUG LOG SESSION ===")
        writeToLogFile("Session started: \(Date())")
        writeToLogFile("Log file: \(logFileURL.path)")
        writeToLogFile("=====================================\n")
    }
    
    // MARK: - Debug Entry
    
    public struct DebugEntry {
        let timestamp: Date
        let category: DebugCategory
        let message: String
        let context: [String: Any]
        
        var formattedOutput: String {
            let timeString = DateFormatter.debugFormatter.string(from: timestamp)
            let contextString = context.isEmpty ? "" : " | Context: \(context)"
            return "[\(timeString)] \(category.rawValue.uppercased()): \(message)\(contextString)"
        }
    }
    
    public enum DebugCategory: String {
        case lifecycle = "lifecycle"
        case menu = "menu"
        case network = "network"
        case state = "state"
        case error = "error"
        case warning = "warning"
        case timer = "timer"
        case verification = "verification"
        case healing = "healing"
    }
    
    // MARK: - Logging Methods
    
    public func log(_ category: DebugCategory, _ message: String, context: [String: Any] = [:]) {
        let entry = DebugEntry(
            timestamp: Date(),
            category: category,
            message: message,
            context: context
        )
        
        debugLog.append(entry)
        
        // Trim log if too large
        if debugLog.count > maxLogEntries {
            debugLog.removeFirst(debugLog.count - maxLogEntries)
        }
        
        // Print to console with appropriate prefix
        let prefix = category == .error ? "❌" : 
                    category == .warning ? "⚠️" : 
                    category == .lifecycle ? "🔄" :
                    category == .network ? "🌐" :
                    category == .timer ? "⏰" :
                    category == .verification ? "🔍" :
                    category == .healing ? "🩹" : "🔧"
        
        let formattedOutput = "\(prefix) \(entry.formattedOutput)"
        print(formattedOutput)
        
        // Write to log file
        writeToLogFile(formattedOutput)
    }
    
    private func writeToLogFile(_ message: String) {
        let logEntry = "\(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logFileURL)
            }
        }
    }
    
    // MARK: - Debug Dump
    
    public func generateDebugReport() -> String {
        var report = """
        
        ======================================
        HARBINGER STATUS BAR DEBUG REPORT
        ======================================
        Generated: \(DateFormatter.debugFormatter.string(from: Date()))
        Log File: \(logFileURL.path)
        
        """
        
        // Recent log entries (last 50)
        report += "\n--- RECENT LOG ENTRIES (Last 50) ---\n"
        let recentEntries = Array(debugLog.suffix(50))
        for entry in recentEntries {
            report += entry.formattedOutput + "\n"
        }
        
        return report
    }
    
    public func getLogFilePath() -> String {
        return logFileURL.path
    }
    
    public func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }
    
    public func getLogEntries(category: DebugCategory? = nil, limit: Int = 100) -> [DebugEntry] {
        let filtered = category != nil ? debugLog.filter { $0.category == category! } : debugLog
        return Array(filtered.suffix(limit))
    }
    
    public func clearLog() {
        debugLog.removeAll()
        log(.lifecycle, "Debug log cleared")
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Status Bar State Verifier

public class StatusBarStateVerifier {
    
    private weak var statusItem: NSStatusItem?
    private weak var menu: NSMenu?
    
    public init(statusItem: NSStatusItem?, menu: NSMenu?) {
        self.statusItem = statusItem
        self.menu = menu
    }
    
    public struct VerificationResult {
        let isHealthy: Bool
        let issues: [String]
        let warnings: [String]
        
        var summary: String {
            if isHealthy && warnings.isEmpty {
                return "✅ All systems healthy"
            } else if isHealthy {
                return "⚠️ Healthy with \(warnings.count) warning(s)"
            } else {
                return "❌ \(issues.count) critical issue(s) found"
            }
        }
    }
    
    public func verifyState() -> VerificationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        StatusBarDebugger.shared.log(.verification, "Starting state verification")
        
        // Check status item existence
        guard let statusItem = statusItem else {
            issues.append("StatusItem is nil")
            return VerificationResult(isHealthy: false, issues: issues, warnings: warnings)
        }
        
        // Check status item properties
        if !statusItem.isVisible {
            issues.append("StatusItem is not visible")
        }
        
        if statusItem.length == 0 {
            warnings.append("StatusItem length is 0")
        }
        
        // Check button
        guard let button = statusItem.button else {
            issues.append("StatusItem button is nil")
            return VerificationResult(isHealthy: false, issues: issues, warnings: warnings)
        }
        
        if button.image == nil && button.title.isEmpty {
            warnings.append("Button has no image or title")
        }
        
        if button.action == nil {
            warnings.append("Button has no action")
        }
        
        if button.target == nil {
            warnings.append("Button has no target")
        }
        
        if button.isHidden {
            issues.append("Button is hidden")
        }
        
        if button.alphaValue < 0.1 {
            issues.append("Button alpha is too low: \(button.alphaValue)")
        }
        
        // Check menu
        if statusItem.menu == nil {
            issues.append("StatusItem has no menu")
        } else if let menu = statusItem.menu {
            if menu.items.isEmpty {
                warnings.append("Menu has no items")
            }
            
            // Check for duplicate menu items
            let titles = menu.items.map { $0.title }
            let uniqueTitles = Set(titles)
            if titles.count != uniqueTitles.count {
                warnings.append("Menu has duplicate items")
            }
            
            // Check for orphaned menu items (no target/action where expected)
            let interactiveItems = menu.items.filter { !$0.isSeparatorItem && $0.isEnabled }
            let orphanedItems = interactiveItems.filter { $0.action != nil && $0.target == nil }
            if !orphanedItems.isEmpty {
                warnings.append("\(orphanedItems.count) menu items have action but no target")
            }
        }
        
        let isHealthy = issues.isEmpty
        let result = VerificationResult(isHealthy: isHealthy, issues: issues, warnings: warnings)
        
        StatusBarDebugger.shared.log(.verification, "Verification complete: \(result.summary)", 
                                   context: ["issues": issues.count, "warnings": warnings.count])
        
        return result
    }
    
    public func logDetailedState() {
        guard let statusItem = statusItem else {
            StatusBarDebugger.shared.log(.state, "StatusItem is nil")
            return
        }
        
        var state: [String: Any] = [:]
        state["isVisible"] = statusItem.isVisible
        state["length"] = statusItem.length
        
        if let button = statusItem.button {
            state["button.title"] = button.title
            state["button.hasImage"] = button.image != nil
            state["button.isHidden"] = button.isHidden
            state["button.alphaValue"] = button.alphaValue
            state["button.hasAction"] = button.action != nil
            state["button.hasTarget"] = button.target != nil
        } else {
            state["button"] = "nil"
        }
        
        if let menu = statusItem.menu {
            state["menu.itemCount"] = menu.items.count
            state["menu.titles"] = menu.items.map { $0.title }
        } else {
            state["menu"] = "nil"
        }
        
        StatusBarDebugger.shared.log(.state, "Detailed state logged", context: state)
    }
}

// MARK: - Self-Healing Manager

public class StatusBarSelfHealer {
    
    private weak var statusBarManager: StatusBarManager?
    
    public init(statusBarManager: StatusBarManager) {
        self.statusBarManager = statusBarManager
        setupSystemNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupSystemNotifications() {
        // Monitor system sleep/wake
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        StatusBarDebugger.shared.log(.lifecycle, "System notifications set up for self-healing")
    }
    
    @objc private func systemWillSleep() {
        StatusBarDebugger.shared.log(.lifecycle, "System will sleep - preparing status bar")
        // Could pause timers, save state, etc.
    }
    
    @objc private func systemDidWake() {
        StatusBarDebugger.shared.log(.lifecycle, "System did wake - verifying status bar")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.performHealthCheck()
        }
    }
    
    @discardableResult
    public func performHealthCheck() -> Bool {
        guard let statusBarManager = statusBarManager else {
            StatusBarDebugger.shared.log(.error, "StatusBarManager is nil during health check")
            return false
        }
        
        let verifier = StatusBarStateVerifier(
            statusItem: statusBarManager.debugStatusItem,
            menu: statusBarManager.debugStatusItem?.menu
        )
        
        let result = verifier.verifyState()
        
        if !result.isHealthy {
            StatusBarDebugger.shared.log(.healing, "Health check failed, attempting recovery", 
                                       context: ["issues": result.issues])
            return attemptHealing(issues: result.issues)
        }
        
        return true
    }
    
    private func attemptHealing(issues: [String]) -> Bool {
        guard let statusBarManager = statusBarManager else { return false }
        
        var healed = false
        
        for issue in issues {
            StatusBarDebugger.shared.log(.healing, "Attempting to heal: \(issue)")
            
            switch issue {
            case let issue where issue.contains("StatusItem is nil"):
                statusBarManager.recreateStatusItem()
                healed = true
                
            case let issue where issue.contains("not visible"):
                if let statusItem = statusBarManager.debugStatusItem {
                    statusItem.isVisible = true
                    healed = true
                }
                
            case let issue where issue.contains("Button is hidden"):
                if let button = statusBarManager.debugStatusItem?.button {
                    button.isHidden = false
                    healed = true
                }
                
            case let issue where issue.contains("alpha is too low"):
                if let button = statusBarManager.debugStatusItem?.button {
                    button.alphaValue = 1.0
                    healed = true
                }
                
            default:
                StatusBarDebugger.shared.log(.warning, "No healing strategy for: \(issue)")
            }
        }
        
        if healed {
            StatusBarDebugger.shared.log(.healing, "Healing attempted, re-verifying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                _ = self?.performHealthCheck()
            }
        }
        
        return healed
    }
}