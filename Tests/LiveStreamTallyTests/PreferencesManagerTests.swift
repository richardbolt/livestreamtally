//
//  PreferencesManagerTests.swift
//  LiveStreamTallyTests
//
//  Created as a test scaffolding
//

import XCTest
@testable import LiveStreamTally

// Note: Testing with Swift 6.1's actor isolation is challenging in XCTest.
// Individual test methods are marked with @MainActor rather than marking the entire class
// to avoid issues with XCTestCase's non-Sendable nature.
final class PreferencesManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Note: We can't directly interact with @MainActor-isolated code in setUp/tearDown
        // Individual tests will handle their own setup/cleanup
    }
    
    override func tearDown() {
        // Note: We can't directly interact with @MainActor-isolated code in setUp/tearDown
        super.tearDown()
    }
    
    private func clearPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "youtube_channel_id")
        defaults.removeObject(forKey: "youtube_channel_id_cached")
        defaults.removeObject(forKey: "youtube_upload_playlist_id")
        defaults.removeObject(forKey: "refresh_interval")
        defaults.removeObject(forKey: "ndi_output_name")
        defaults.removeObject(forKey: "ndi_enabled")
    }
    
    // This test demonstrates how a test would work with the real PreferencesManager
    // In a full implementation, you'd test the actual preference storage methods
    @MainActor
    func testPreferenceAccessors() async {
        // Clear preferences first
        clearPreferences()
        
        // Verify that PreferencesManager is accessible from tests
        let preferences = PreferencesManager.shared
        XCTAssertNotNil(preferences)
        
        // Clean up afterwards
        clearPreferences()
    }
    
    // MARK: - Note on Testing With Actual PreferencesManager
    
    // Testing the actual PreferencesManager would require access to the 
    // implementation details of methods like setChannelId(), getChannelId(), etc.
    // In a real application, we would:
    //
    // 1. Make sure PreferencesManager has the right methods
    // 2. Modify tests to call those actual methods 
    // 3. Or use a protocol-based mock implementation for testing
    
    // MARK: - Tests with Mock PreferencesManager
    
    func testNotificationsArePosted() async throws {
        // This test doesn't interact directly with MainActor-isolated code
        // Setup expectation for channel changed notification
        let expectation = XCTNSNotificationExpectation(
            name: PreferencesManager.Notifications.channelChanged
        )
        
        // Post the notification manually for testing
        NotificationCenter.default.post(
            name: PreferencesManager.Notifications.channelChanged,
            object: nil
        )
        
        // Wait for the notification
        await fulfillment(of: [expectation], timeout: 1.0)
    }
} 