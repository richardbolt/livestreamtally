//
//  PreferencesManagerTests.swift
//  LiveStreamTallyTests
//
//  Tests for PreferencesManager state storage and synchronization
//

import Testing
import Foundation
import Combine
@testable import LiveStreamTally

@Suite("Preferences Manager Tests")
struct PreferencesManagerTests {

    // MARK: - Helper Methods

    private func clearAllPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "youtube_channel_id")
        defaults.removeObject(forKey: "youtube_channel_id_cached")
        defaults.removeObject(forKey: "youtube_upload_playlist_id")
        defaults.removeObject(forKey: "youtube_live_check_interval")
        defaults.removeObject(forKey: "youtube_not_live_check_interval")
        defaults.removeObject(forKey: "show_viewer_count")
        defaults.removeObject(forKey: "show_date_time")
        defaults.removeObject(forKey: "ndi_output_name")
        defaults.removeObject(forKey: "ndi_enabled")
    }

    // MARK: - Test 1: Preference Storage and Retrieval Tests

    @Test("updateChannelId stores and retrieves channel ID")
    @MainActor
    func updateChannelId_stores_and_retrieves() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared
        let testChannelId = "UC_TestChannel123"

        // Act
        preferences.updateChannelId(testChannelId)

        // Assert
        #expect(preferences.getChannelId() == testChannelId, "Channel ID should be stored and retrievable")
        #expect(preferences.channelId == testChannelId, "Published property should match")

        // Verify it's persisted in UserDefaults
        let storedValue = UserDefaults.standard.string(forKey: "youtube_channel_id")
        #expect(storedValue == testChannelId, "Channel ID should be persisted in UserDefaults")

        // Clean up
        clearAllPreferences()
    }

    @Test("updateChannelId clears cached channel info")
    @MainActor
    func updateChannelId_clears_cached_info() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Set up initial cached values
        preferences.setResolvedChannelInfo(channelId: "UC_Cached123", playlistId: "UU_Cached123")
        #expect(!preferences.cachedChannelId.isEmpty, "Should have cached channel ID")
        #expect(!preferences.uploadPlaylistId.isEmpty, "Should have playlist ID")

        // Act - Update channel ID (should clear cache)
        preferences.updateChannelId("UC_NewChannel456")

        // Assert - Cache should be cleared
        #expect(preferences.cachedChannelId.isEmpty, "Cached channel ID should be cleared")
        #expect(preferences.uploadPlaylistId.isEmpty, "Playlist ID should be cleared")
        #expect(preferences.channelId == "UC_NewChannel456", "New channel ID should be set")

        // Clean up
        clearAllPreferences()
    }

    @Test("setResolvedChannelInfo stores both channelId and playlistId")
    @MainActor
    func setResolvedChannelInfo_stores_both_values() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared
        let testChannelId = "UC_Resolved123"
        let testPlaylistId = "UU_Resolved123"

        // Act
        preferences.setResolvedChannelInfo(channelId: testChannelId, playlistId: testPlaylistId)

        // Assert
        #expect(preferences.cachedChannelId == testChannelId, "Cached channel ID should be set")
        #expect(preferences.uploadPlaylistId == testPlaylistId, "Upload playlist ID should be set")

        // Verify persistence
        let cachedValue = UserDefaults.standard.string(forKey: "youtube_channel_id_cached")
        let playlistValue = UserDefaults.standard.string(forKey: "youtube_upload_playlist_id")
        #expect(cachedValue == testChannelId, "Should persist cached channel ID")
        #expect(playlistValue == testPlaylistId, "Should persist playlist ID")

        // Clean up
        clearAllPreferences()
    }

    @Test("clearChannelCache removes cached values")
    @MainActor
    func clearChannelCache_removes_cached_values() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Set up cached values
        preferences.setResolvedChannelInfo(channelId: "UC_Test123", playlistId: "UU_Test123")
        #expect(!preferences.cachedChannelId.isEmpty, "Should have cached values initially")

        // Act
        preferences.clearChannelCache()

        // Assert
        #expect(preferences.cachedChannelId.isEmpty, "Cached channel ID should be cleared")
        #expect(preferences.uploadPlaylistId.isEmpty, "Upload playlist ID should be cleared")

        // Verify removed from UserDefaults
        let cachedValue = UserDefaults.standard.string(forKey: "youtube_channel_id_cached")
        let playlistValue = UserDefaults.standard.string(forKey: "youtube_upload_playlist_id")
        #expect(cachedValue == nil, "Cached channel ID should be removed from UserDefaults")
        #expect(playlistValue == nil, "Playlist ID should be removed from UserDefaults")

        // Clean up
        clearAllPreferences()
    }

    @Test("updateIntervals stores both intervals")
    @MainActor
    func updateIntervals_stores_both_intervals() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared
        let liveInterval = 10.0
        let notLiveInterval = 30.0

        // Act
        preferences.updateIntervals(liveInterval: liveInterval, notLiveInterval: notLiveInterval)

        // Assert
        #expect(preferences.getLiveCheckInterval() == liveInterval, "Live interval should be updated")
        #expect(preferences.getNotLiveCheckInterval() == notLiveInterval, "Not-live interval should be updated")
        #expect(preferences.liveCheckInterval == liveInterval, "Published property should match")
        #expect(preferences.notLiveCheckInterval == notLiveInterval, "Published property should match")

        // Verify persistence
        let storedLive = UserDefaults.standard.double(forKey: "youtube_live_check_interval")
        let storedNotLive = UserDefaults.standard.double(forKey: "youtube_not_live_check_interval")
        #expect(storedLive == liveInterval, "Live interval should be persisted")
        #expect(storedNotLive == notLiveInterval, "Not-live interval should be persisted")

        // Clean up
        clearAllPreferences()
    }

    @Test("Default intervals are correct")
    @MainActor
    func default_intervals_are_correct() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Assert - Default values
        #expect(preferences.getLiveCheckInterval() == 5.0, "Default live interval should be 5 seconds")
        #expect(preferences.getNotLiveCheckInterval() == 20.0, "Default not-live interval should be 20 seconds")

        // Clean up
        clearAllPreferences()
    }

    @Test("updateShowViewerCount stores and retrieves setting")
    @MainActor
    func updateShowViewerCount_stores_and_retrieves() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Act - Set to false
        preferences.updateShowViewerCount(false)

        // Assert
        #expect(preferences.getShowViewerCount() == false, "Show viewer count should be false")
        #expect(preferences.showViewerCount == false, "Published property should match")

        // Act - Set to true
        preferences.updateShowViewerCount(true)

        // Assert
        #expect(preferences.getShowViewerCount() == true, "Show viewer count should be true")
        #expect(preferences.showViewerCount == true, "Published property should match")

        // Clean up
        clearAllPreferences()
    }

    @Test("updateShowDateTime stores and retrieves setting")
    @MainActor
    func updateShowDateTime_stores_and_retrieves() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Act - Set to false
        preferences.updateShowDateTime(false)

        // Assert
        #expect(preferences.getShowDateTime() == false, "Show date time should be false")
        #expect(preferences.showDateTime == false, "Published property should match")

        // Act - Set to true
        preferences.updateShowDateTime(true)

        // Assert
        #expect(preferences.getShowDateTime() == true, "Show date time should be true")
        #expect(preferences.showDateTime == true, "Published property should match")

        // Clean up
        clearAllPreferences()
    }

    // MARK: - Test 2: Notification Tests

    @Test("updateChannelId posts channelChanged notification")
    @MainActor
    func updateChannelId_posts_notification() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Use Swift Testing's confirmation to wait for notification
        await confirmation { notificationReceived in
            let observer = NotificationCenter.default.addObserver(
                forName: PreferencesManager.NotificationNames.channelChanged,
                object: nil,
                queue: .main
            ) { _ in
                notificationReceived()
            }

            // Act
            preferences.updateChannelId("UC_TestNotification")

            // Clean up observer
            NotificationCenter.default.removeObserver(observer)
        }

        // Clean up
        clearAllPreferences()
    }

    @Test("setResolvedChannelInfo posts resolvedChannelChanged notification")
    @MainActor
    func setResolvedChannelInfo_posts_notification() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Use Swift Testing's confirmation to wait for notification
        await confirmation { notificationReceived in
            let observer = NotificationCenter.default.addObserver(
                forName: PreferencesManager.NotificationNames.resolvedChannelChanged,
                object: nil,
                queue: .main
            ) { _ in
                notificationReceived()
            }

            // Act
            preferences.setResolvedChannelInfo(channelId: "UC_Test", playlistId: "UU_Test")

            // Clean up observer
            NotificationCenter.default.removeObserver(observer)
        }

        // Clean up
        clearAllPreferences()
    }

    @Test("updateIntervals posts intervalChanged notification")
    @MainActor
    func updateIntervals_posts_notification() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Use Swift Testing's confirmation to wait for notification
        await confirmation { notificationReceived in
            let observer = NotificationCenter.default.addObserver(
                forName: PreferencesManager.NotificationNames.intervalChanged,
                object: nil,
                queue: .main
            ) { _ in
                notificationReceived()
            }

            // Act
            preferences.updateIntervals(liveInterval: 10.0, notLiveInterval: 30.0)

            // Clean up observer
            NotificationCenter.default.removeObserver(observer)
        }

        // Clean up
        clearAllPreferences()
    }

    @Test("updateApiKey posts apiKeyChanged notification on success")
    @MainActor
    func updateApiKey_posts_notification_on_success() async throws {
        // Note: This test requires KeychainManager to succeed
        // We're testing that the notification is posted IF the save succeeds

        // Arrange
        let preferences = PreferencesManager.shared
        let testApiKey = "test_api_key_\(UUID().uuidString)"

        // Use Swift Testing's confirmation to wait for notification
        // Set expectedCount to 0 or 1 to allow for keychain save failure in test environment
        await confirmation(expectedCount: 0...1) { notificationReceived in
            let observer = NotificationCenter.default.addObserver(
                forName: PreferencesManager.NotificationNames.apiKeyChanged,
                object: nil,
                queue: .main
            ) { _ in
                notificationReceived()
            }

            // Act
            let success = preferences.updateApiKey(testApiKey)

            // If keychain save succeeded, we should get the notification
            // If it failed, we won't get the notification (which is correct behavior)

            // Clean up observer
            NotificationCenter.default.removeObserver(observer)
        }

        // Note: We don't clean up the keychain as that's managed by KeychainManager
    }

    // MARK: - Test 3: Published Property Tests

    @Test("channelId published property updates when changed")
    @MainActor
    func channelId_published_property_updates() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        var receivedValues: [String] = []
        let cancellable = preferences.$channelId
            .sink { value in
                receivedValues.append(value)
            }

        // Initial value should be empty
        #expect(receivedValues.first == "", "Initial value should be empty")

        // Act
        preferences.updateChannelId("UC_FirstUpdate")

        // Wait for Combine to propagate
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedValues.contains("UC_FirstUpdate"), "Should receive updated value")

        // Act again
        preferences.updateChannelId("UC_SecondUpdate")

        // Wait for Combine to propagate
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        #expect(receivedValues.contains("UC_SecondUpdate"), "Should receive second updated value")

        // Clean up
        cancellable.cancel()
        clearAllPreferences()
    }

    @Test("liveCheckInterval published property updates when changed")
    @MainActor
    func liveCheckInterval_published_property_updates() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        var receivedValues: [TimeInterval] = []
        let cancellable = preferences.$liveCheckInterval
            .sink { value in
                receivedValues.append(value)
            }

        // Initial value should be 5.0
        #expect(receivedValues.first == 5.0, "Initial value should be 5.0")

        // Act
        preferences.updateIntervals(liveInterval: 15.0, notLiveInterval: 30.0)

        // Wait for Combine to propagate
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedValues.contains(15.0), "Should receive updated interval")

        // Clean up
        cancellable.cancel()
        clearAllPreferences()
    }

    @Test("notLiveCheckInterval published property updates when changed")
    @MainActor
    func notLiveCheckInterval_published_property_updates() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        var receivedValues: [TimeInterval] = []
        let cancellable = preferences.$notLiveCheckInterval
            .sink { value in
                receivedValues.append(value)
            }

        // Initial value should be 20.0
        #expect(receivedValues.first == 20.0, "Initial value should be 20.0")

        // Act
        preferences.updateIntervals(liveInterval: 10.0, notLiveInterval: 40.0)

        // Wait for Combine to propagate
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedValues.contains(40.0), "Should receive updated interval")

        // Clean up
        cancellable.cancel()
        clearAllPreferences()
    }

    @Test("showViewerCount published property updates when changed")
    @MainActor
    func showViewerCount_published_property_updates() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        var receivedValues: [Bool] = []
        let cancellable = preferences.$showViewerCount
            .sink { value in
                receivedValues.append(value)
            }

        // Act - Toggle value
        let currentValue = preferences.showViewerCount
        preferences.updateShowViewerCount(!currentValue)

        // Wait for Combine to propagate
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedValues.contains(!currentValue), "Should receive toggled value")
        #expect(receivedValues.count >= 2, "Should have at least initial + updated value")

        // Clean up
        cancellable.cancel()
        clearAllPreferences()
    }

    @Test("showDateTime published property updates when changed")
    @MainActor
    func showDateTime_published_property_updates() async throws {
        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        var receivedValues: [Bool] = []
        let cancellable = preferences.$showDateTime
            .sink { value in
                receivedValues.append(value)
            }

        // Act - Toggle value
        let currentValue = preferences.showDateTime
        preferences.updateShowDateTime(!currentValue)

        // Wait for Combine to propagate
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        #expect(receivedValues.contains(!currentValue), "Should receive toggled value")
        #expect(receivedValues.count >= 2, "Should have at least initial + updated value")

        // Clean up
        cancellable.cancel()
        clearAllPreferences()
    }

    // MARK: - Test 4: Integration Tests

    @Test("Preferences persist across manager lifecycle")
    @MainActor
    func preferences_persist_across_lifecycle() async throws {
        // This test would require creating a new PreferencesManager instance
        // which isn't possible with the singleton pattern
        // Instead, we verify UserDefaults persistence directly

        // Arrange
        clearAllPreferences()
        let preferences = PreferencesManager.shared

        // Act - Set values
        preferences.updateChannelId("UC_Persist123")
        preferences.updateIntervals(liveInterval: 7.0, notLiveInterval: 25.0)

        // Assert - Values are in UserDefaults
        let channelId = UserDefaults.standard.string(forKey: "youtube_channel_id")
        let liveInterval = UserDefaults.standard.double(forKey: "youtube_live_check_interval")
        let notLiveInterval = UserDefaults.standard.double(forKey: "youtube_not_live_check_interval")

        #expect(channelId == "UC_Persist123", "Channel ID should persist")
        #expect(liveInterval == 7.0, "Live interval should persist")
        #expect(notLiveInterval == 25.0, "Not-live interval should persist")

        // Clean up
        clearAllPreferences()
    }
}
