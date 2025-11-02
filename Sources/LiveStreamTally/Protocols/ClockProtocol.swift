//
//  ClockProtocol.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation

/// Protocol for time operations to enable deterministic testing
protocol ClockProtocol: Sendable {
    /// Returns the current date and time
    func now() -> Date

    /// Sleeps for the specified duration
    /// - Parameter duration: The duration to sleep in seconds
    func sleep(for duration: TimeInterval) async throws
}

/// System clock implementation using real time
struct SystemClock: ClockProtocol {
    func now() -> Date {
        return Date()
    }

    func sleep(for duration: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}
