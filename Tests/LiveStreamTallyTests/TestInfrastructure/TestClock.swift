//
//  TestClock.swift
//  LiveStreamTallyTests
//
//  Test infrastructure for deterministic time-based testing
//

import Foundation
@testable import LiveStreamTally

/// Test clock that provides deterministic time control for testing
@MainActor
final class TestClock: ClockProtocol {
    private var currentTime: Date

    /// Initialize with a starting time
    /// - Parameter startTime: The initial time (defaults to current time)
    init(startTime: Date = Date()) {
        self.currentTime = startTime
    }

    /// Returns the current simulated time
    func now() -> Date {
        return currentTime
    }

    /// Advances the simulated time by the specified duration
    /// - Parameter duration: The duration to advance in seconds
    func advance(by duration: TimeInterval) async {
        currentTime = currentTime.addingTimeInterval(duration)
    }

    /// No-op sleep for tests - time is controlled manually via advance()
    /// - Parameter duration: Ignored in test clock
    func sleep(for duration: TimeInterval) async throws {
        // No-op in tests - time is controlled manually
    }

    /// Resets the clock to a specific time
    /// - Parameter time: The time to reset to
    func reset(to time: Date) {
        currentTime = time
    }
}
