#!/usr/bin/env swift

import Foundation

// Simple script to get the latest Harbinger log file path
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let logsDirectory = documentsPath.appendingPathComponent("HarbingerLogs")

do {
    let logFiles = try FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey], options: [])
    
    let sortedFiles = logFiles.sorted { file1, file2 in
        let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
        let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
        return date1 > date2
    }
    
    if let latestLog = sortedFiles.first {
        print("Latest Harbinger log file:")
        print(latestLog.path)
        print("\nTo view the log:")
        print("cat '\(latestLog.path)'")
        print("\nTo tail the log (follow new entries):")
        print("tail -f '\(latestLog.path)'")
    } else {
        print("No log files found in \(logsDirectory.path)")
    }
} catch {
    print("Error reading log directory: \(error)")
    print("Log directory should be: \(logsDirectory.path)")
}