//
//  CoreBehaviorTests.swift
//  LiveStreamTallyTests
//
//  Core behavior tests that verify end-to-end application functionality
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("Core Behavior Tests")
struct CoreBehaviorTests {

    // MARK: - Test 1: ON AIR Success Flow

    @Test("ON AIR success updates UI and NDI correctly")
    @MainActor
    func onAir_success_updates_UI_and_NDI() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(
            isLive: true,
            viewerCount: 1250,
            title: "Live Coding Stream",
            videoId: "abc123"
        )

        let ndiSpy = NDISpy()
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

        // Give monitoring a moment to complete the first check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.1 seconds

        // Assert - ViewModel state
        #expect(vm.isLive == true, "ViewModel should show live state")
        #expect(vm.viewerCount == 1250, "ViewModel should show correct viewer count")
        #expect(vm.title == "Live Coding Stream", "ViewModel should show correct title")
        #expect(vm.error == nil, "ViewModel should have no error")

        // Assert - Service was called
        #expect(fakeService.checkLiveStatusCalled, "YouTube service should have been called")
        #expect(fakeService.lastChannelId == "UC12345", "Service should be called with correct channel ID")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 2: OFF AIR State

    @Test("No live stream shows OFF AIR state correctly")
    @MainActor
    func noLiveStream_shows_offAir_state() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(
            isLive: false,
            viewerCount: 0,
            title: "",
            videoId: "abc123"
        )

        let ndiSpy = NDISpy()
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

        // Give monitoring a moment to complete the first check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.25 seconds

        // Assert - ViewModel state
        #expect(vm.isLive == false, "ViewModel should show not live state")
        #expect(vm.viewerCount == 0, "ViewModel should show zero viewers")
        #expect(vm.title == "", "ViewModel should show empty title")
        #expect(vm.error == nil, "ViewModel should have no error")

        // Assert - Service was called
        #expect(fakeService.checkLiveStatusCalled, "YouTube service should have been called")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 3: API Quota Exceeded

    @Test("Quota exceeded shows error message to user")
    @MainActor
    func quotaExceeded_shows_error_and_continues_monitoring() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextError = YouTubeError.quotaExceeded

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

        // Give monitoring a moment to complete the first check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.1 seconds

        // Assert - Error is shown
        #expect(vm.error != nil, "ViewModel should show an error")
        #expect(vm.error?.contains("quota") ?? false, "Error should mention quota")

        // Assert - Service was called
        #expect(fakeService.checkLiveStatusCalled, "YouTube service should have been called")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 4: Invalid API Key

    @Test("Invalid API key shows error prompting user to check key")
    @MainActor
    func invalidApiKey_shows_error_to_user() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextError = YouTubeError.invalidApiKey

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

        // Give monitoring a moment to complete the first check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.1 seconds

        // Assert - Error is shown
        #expect(vm.error != nil, "ViewModel should show an error")

        // Assert - Service was called
        #expect(fakeService.checkLiveStatusCalled, "YouTube service should have been called")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 5: ON AIR to OFF AIR Transition

    @Test("ON AIR to OFF AIR transition updates state correctly")
    @MainActor
    func onAir_to_offAir_transition_updates_state() async throws {
        // Arrange - Create service with script that keeps returning ON AIR, then OFF AIR
        let fakeService = FakeYouTubeService(script: [
            LiveStatus(isLive: true, viewerCount: 123, title: "Live!", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 123, title: "Live!", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 123, title: "Live!", videoId: "abc"),
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")
        ])

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"
        prefs.liveCheckInterval = 0.3 // Fast polling for test
        prefs.notLiveCheckInterval = 0.3

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring
        await vm.startMonitoring()

        // Wait for first check to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Assert - Initial ON AIR state
        #expect(vm.isLive == true, "Initially should be live")
        #expect(vm.viewerCount == 123, "Initially should have 123 viewers")
        #expect(vm.title == "Live!", "Initially should have correct title")

        // Act - Wait for enough polls to get to the OFF AIR status (3 more polls)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second (3+ polls at 0.3s each)

        // Assert - Transitioned to OFF AIR
        #expect(vm.isLive == false, "Should transition to not live")
        #expect(vm.viewerCount == 0, "Should have zero viewers")
        #expect(vm.title == "", "Should have empty title")

        // Clean up
        await vm.stopMonitoring()
    }

    // MARK: - Test 6: Preferences Change Restarts Polling

    @Test("Channel ID change restarts polling with new channel")
    @MainActor
    func channelIdChange_restarts_polling_with_new_channel() async throws {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(
            isLive: true,
            viewerCount: 100,
            title: "Channel A Stream",
            videoId: "abc"
        )

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC_ChannelA"
        prefs.cachedChannelId = "UC_ChannelA"
        prefs.uploadPlaylistId = "UU_ChannelA"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start monitoring with Channel A
        await vm.startMonitoring()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.25 seconds

        // Assert - Initial check with Channel A
        #expect(fakeService.lastChannelId == "UC_ChannelA", "Should check Channel A initially")

        // Act - Change to Channel B (simulate user changing preference)
        fakeService.nextStatus = LiveStatus(
            isLive: true,
            viewerCount: 200,
            title: "Channel B Stream",
            videoId: "def"
        )

        // Update channel ID - this should trigger cache clear and restart
        vm.updateChannelId("UC_ChannelB")

        // Wait for the change to propagate and monitoring to restart
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Assert - Cache was cleared
        #expect(fakeService.clearCacheCalled, "Service cache should be cleared on channel change")

        // Assert - New channel ID is set in preferences
        #expect(prefs.channelId == "UC_ChannelB", "Preferences should have new channel ID")
        #expect(prefs.cachedChannelId == "", "Cached channel ID should be cleared")
        #expect(prefs.uploadPlaylistId == "", "Upload playlist ID should be cleared")

        // Clean up
        await vm.stopMonitoring()
    }
}
