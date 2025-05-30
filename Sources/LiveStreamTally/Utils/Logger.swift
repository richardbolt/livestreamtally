//
//  Logger.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import os
import OSLog

enum LogCategory: String {
    case main = "MainViewModel"
    case youtube = "YouTubeService"
    case app = "Application"
    case settings = "Settings"
}

/// A centralized logging utility for the application
struct Logger {
    private static let subsystem = "com.richardbolt.livestreamtally"
    
    static func logger(for category: LogCategory) -> OSLog {
        return OSLog(subsystem: subsystem, category: category.rawValue)
    }
    
    /// Log an info message
    static func info(_ message: String, category: LogCategory, file: String = #file, line: Int = #line) {
        let log = logger(for: category)
        os_log("%{public}@", log: log, type: .info, message)
    }
    
    /// Log a debug message
    static func debug(_ message: String, category: LogCategory, file: String = #file, line: Int = #line) {
        let log = logger(for: category)
        os_log("%{public}@", log: log, type: .debug, message)
    }
    
    /// Log an error message
    static func error(_ message: String, category: LogCategory, file: String = #file, line: Int = #line) {
        let log = logger(for: category)
        os_log("%{public}@", log: log, type: .error, message)
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: LogCategory, file: String = #file, line: Int = #line) {
        let log = logger(for: category)
        os_log("%{public}@", log: log, type: .default, message)
    }
} 