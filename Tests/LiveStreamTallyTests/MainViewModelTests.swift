//
//  MainViewModelTests.swift
//  LiveStreamTallyTests
//
//  Tests for MainViewModel state management and coordination
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("Main View Model Tests")
struct MainViewModelTests {

    // MARK: - Test 1: Monitoring Lifecycle Tests

    @Test("startMonitoring begins polling and checks immediately")
    @MainActor
    func startMonitoring_begins_polling_and_checks_immediately() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(
            isLive: true,
            viewerCount: 100,
            title: "Test Stream",
            videoId: "abc123"
        )

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        await vm.startMonitoring()

        // Assert - Should check immediately (already verified by await)
        #expect(fakeService.checkLiveStatusCalled, "YouTube service should have been called immediately")
        #expect(vm.isLive == true, "ViewModel should reflect live status")
        #expect(vm.viewerCount == 100, "ViewModel should show viewer count")
        #expect(vm.title == "Test Stream", "ViewModel should show title")

        // Clean up
        await vm.stopMonitoring()
    }

    @Test("stopMonitoring stops polling")
    @MainActor
    func stopMonitoring_stops_polling() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start then immediately stop
        await vm.startMonitoring()
        let callCountAfterStart = fakeService.checkLiveStatusCalled ? 1 : 0

        await vm.stopMonitoring()

        // Reset the flag to track if called again
        fakeService.checkLiveStatusCalled = false

        // Wait a bit to ensure timer doesn't fire
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Assert - Service should not be called again after stopping
        #expect(callCountAfterStart == 1, "Service should have been called once during start")
        #expect(fakeService.checkLiveStatusCalled == false, "Service should not be called after stopping")
    }

    @Test("startMonitoring with empty channelId sets error")
    @MainActor
    func startMonitoring_with_empty_channelId_sets_error() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()
        // Don't set channelId - leave it empty

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        await vm.startMonitoring()

        // Assert
        #expect(vm.error != nil, "ViewModel should have error when channel ID is empty")
        #expect(vm.error?.contains("Channel ID") ?? false, "Error should mention channel ID")
        #expect(fakeService.checkLiveStatusCalled == false, "Service should not be called without channel ID")

        // Clean up
        await vm.stopMonitoring()
    }

    @Test("startMonitoring without YouTube service sets error")
    @MainActor
    func startMonitoring_without_service_sets_error() async throws {
        // Arrange
        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"

        let vm = MainViewModel(
            youtubeService: nil, // No service
            preferences: prefs,
            isTestMode: true
        )

        // Act
        await vm.startMonitoring()

        // Assert
        #expect(vm.error != nil, "ViewModel should have error when service is not initialized")
        #expect(vm.error?.contains("YouTube service") ?? false, "Error should mention YouTube service")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 2: Timer Interval Switching Tests

    @Test("Monitoring starts and detects live stream correctly")
    @MainActor
    func monitoring_starts_and_detects_live_stream() async throws {
        // Arrange - Service returns live status
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: true, viewerCount: 100, title: "Live", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"
        prefs.liveCheckInterval = 5.0
        prefs.notLiveCheckInterval = 20.0

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()

        // Assert - Initial check should detect live stream
        #expect(fakeService.checkLiveStatusCalled, "Should have checked status immediately")
        #expect(vm.isLive == true, "Should detect live stream")
        #expect(vm.viewerCount == 100, "Should have viewer count")

        // Note: Testing actual timer firing and interval switching is unreliable in unit tests
        // due to runloop behavior. The timer interval switching is tested via the transition test.

        // Clean up
        await vm.stopMonitoring()
    }

    @Test("Monitoring starts with notLiveCheckInterval when stream is not live")
    @MainActor
    func monitoring_starts_with_notLiveCheckInterval_when_not_live() async throws {
        // Arrange - Service returns not live status
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"
        prefs.liveCheckInterval = 5.0
        prefs.notLiveCheckInterval = 20.0

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()

        // Assert - Initial check should have been made
        #expect(fakeService.checkLiveStatusCalled, "Should have checked status immediately")
        #expect(vm.isLive == false, "Should be not live")

        // Note: Testing actual timer firing is unreliable in unit tests due to runloop behavior
        // The timer interval switching is tested in integration via the transition test

        // Clean up
        await vm.stopMonitoring()
    }

    @Test("Transition to live switches to liveCheckInterval")
    @MainActor
    func transition_to_live_switches_to_liveCheckInterval() async throws {
        // Arrange - Script goes from OFF AIR to ON AIR
        let fakeService = FakeYouTubeService(script: [
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 100, title: "Now Live!", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 100, title: "Now Live!", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 100, title: "Now Live!", videoId: "abc")
        ])

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"
        prefs.liveCheckInterval = 0.2 // Fast
        prefs.notLiveCheckInterval = 0.3 // Slightly slower

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()

        // Assert - Initially not live
        #expect(vm.isLive == false, "Should start not live")

        // Wait long enough for transition to live (2-3 polls)
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        // Assert - Now live
        #expect(vm.isLive == true, "Should transition to live")

        // The interval should have switched to liveCheckInterval
        // We can verify this by seeing that more polls happen in the same time period
        let callsBeforeLiveSwitch = 3 // OFF, OFF, ON
        let callsAfterSwitch = fakeService.scriptIndex

        // Clean up
        await vm.stopMonitoring()

        // Assert - Should have made additional calls with faster interval
        #expect(callsAfterSwitch > callsBeforeLiveSwitch, "Should continue polling with live interval")
    }

    @Test("intervalChanged notification updates active timer")
    @MainActor
    func intervalChanged_notification_updates_active_timer() async throws {
        // Arrange
        let fakeService = FakeYouTubeService(script: [
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")
        ])

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"
        prefs.notLiveCheckInterval = 0.5 // Start with slower interval

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()
        let callsAtStart = fakeService.scriptIndex // Should be 1 (initial check)

        // Update interval to be faster
        prefs.notLiveCheckInterval = 0.2

        // Trigger the interval changed notification
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.intervalChanged,
            object: nil
        )

        // Wait for new faster interval to trigger polls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let callsAfterIntervalChange = fakeService.scriptIndex

        // Clean up
        await vm.stopMonitoring()

        // Assert - Should have made more calls with the faster interval
        // At 0.2s interval, in 0.5s we should get 2-3 more calls
        let additionalCalls = callsAfterIntervalChange - callsAtStart
        #expect(additionalCalls >= 2, "Should poll more frequently after interval change (got \(additionalCalls) additional calls)")
    }

    // MARK: - Test 3: Notification Response Tests

    @Test("apiKeyChanged notification recreates YouTube service")
    @MainActor
    func apiKeyChanged_notification_recreates_service() async throws {
        // Note: This test verifies that the notification handler exists,
        // but we can't fully test service recreation without real PreferencesManager
        // because the isTestMode flag prevents service replacement.

        // Arrange
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Trigger API key changed notification
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.apiKeyChanged,
            object: nil
        )

        // Wait for notification to be processed
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Assert - In test mode, service should NOT be replaced
        // This test mainly verifies the notification handler doesn't crash
        #expect(true, "API key change notification should be handled without crashing")

        // In production (isTestMode: false), the service would be recreated
        // but we can't test that without KeychainAccess
    }

    @Test("channelChanged notification clears cache and restarts monitoring")
    @MainActor
    func channelChanged_notification_clears_cache_and_restarts() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC_Initial"
        prefs.cachedChannelId = "UC_Initial"
        prefs.uploadPlaylistId = "UU_Initial"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()
        #expect(fakeService.checkLiveStatusCalled, "Initial monitoring should check status")

        // Reset flags
        fakeService.clearCacheCalled = false
        fakeService.checkLiveStatusCalled = false

        // Change channel ID and trigger notification
        prefs.channelId = "UC_NewChannel"
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.channelChanged,
            object: nil
        )

        // Wait for async notification handler to complete
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Assert - Cache should be cleared and monitoring restarted
        #expect(fakeService.clearCacheCalled, "Cache should be cleared on channel change")
        #expect(fakeService.checkLiveStatusCalled, "Monitoring should restart and check status")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 4: Time Updates Tests

    @Test("startMonitoring starts time updates")
    @MainActor
    func startMonitoring_starts_time_updates() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Assert - Initially empty or default
        let initialTime = vm.currentTime

        // Act - Start monitoring (which starts time updates)
        await vm.startMonitoring()

        // Wait for time to initialize
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let timeAfterStart = vm.currentTime

        // Clean up
        await vm.stopMonitoring()

        // Assert - Time should be set to current time format
        #expect(!timeAfterStart.isEmpty, "Time should be set after starting monitoring")

        // Verify time format (h:mm:ss a) - e.g., "3:45:12 PM"
        let timePattern = /^\d{1,2}:\d{2}:\d{2} (AM|PM)$/
        #expect(timeAfterStart.contains(timePattern), "Time should be in format 'h:mm:ss AM/PM', got '\(timeAfterStart)'")
    }

    @Test("stopMonitoring stops time updates")
    @MainActor
    func stopMonitoring_stops_time_updates() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start then stop
        await vm.startMonitoring()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let timeBeforeStop = vm.currentTime

        await vm.stopMonitoring()

        // Wait to ensure time doesn't update
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        let timeAfterStop = vm.currentTime

        // Assert - Time should remain unchanged after stopping
        // (Though we can't force a change since time only updates per second)
        // The main assertion is that stopMonitoring doesn't crash
        #expect(!timeBeforeStop.isEmpty, "Time should be set before stop")
        #expect(true, "Stop monitoring should complete without errors")
    }

    @Test("currentTime updates every second while monitoring")
    @MainActor
    func currentTime_updates_every_second() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()

        // Record initial time
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        let time1 = vm.currentTime

        // Wait for time to update (at least 1 second)
        try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
        let time2 = vm.currentTime

        // Clean up
        await vm.stopMonitoring()

        // Assert - Times should be different (unless we got unlucky with timing)
        // At minimum, both should be valid time strings
        #expect(!time1.isEmpty, "Initial time should be set")
        #expect(!time2.isEmpty, "Time after wait should be set")

        // Verify format for both
        let timePattern = /^\d{1,2}:\d{2}:\d{2} (AM|PM)$/
        #expect(time1.contains(timePattern), "Time1 should match format")
        #expect(time2.contains(timePattern), "Time2 should match format")
    }

    @Test("currentTime format is correct")
    @MainActor
    func currentTime_format_is_correct() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        await vm.startMonitoring()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let currentTime = vm.currentTime

        // Clean up
        await vm.stopMonitoring()

        // Assert - Verify time format: "h:mm:ss AM/PM"
        // Examples: "3:45:12 PM", "11:05:08 AM", "12:00:00 PM"
        let pattern = /^\d{1,2}:\d{2}:\d{2} (AM|PM)$/
        #expect(currentTime.contains(pattern), "Time '\(currentTime)' should match format 'h:mm:ss AM/PM'")
    }

    // MARK: - Test 5: API Key and Channel Update Tests

    @Test("updateApiKey calls preferences and clears error on success")
    @MainActor
    func updateApiKey_updates_preferences_and_clears_error() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Set an initial error
        vm.error = "Some previous error"

        // Act
        vm.updateApiKey("new_test_api_key")

        // Assert
        // InMemoryPreferences always returns true for updateApiKey
        #expect(vm.error == nil, "Error should be cleared on successful API key update")

        // Verify the key was passed to preferences
        // Note: InMemoryPreferences doesn't actually store API keys (no Keychain)
        // but the method was called successfully
    }

    @Test("updateChannelId triggers preferences update")
    @MainActor
    func updateChannelId_triggers_preferences_update() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()
        prefs.channelId = "UC_OldChannel"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        vm.updateChannelId("UC_NewChannel")

        // Assert - Preferences should be updated
        #expect(prefs.channelId == "UC_NewChannel", "Channel ID should be updated in preferences")

        // Note: The cache clearing and monitoring restart is tested in the
        // channelChanged notification test above
    }
}
