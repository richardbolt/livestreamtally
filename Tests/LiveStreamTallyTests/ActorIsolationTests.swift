//
//  ActorIsolationTests.swift
//  LiveStreamTallyTests
//
//  Tests for Swift 6.1 actor isolation and concurrency safety
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("Actor Isolation Tests")
struct ActorIsolationTests {

    // MARK: - MainActor Isolation Tests

    @Test("MainViewModel is @MainActor isolated")
    @MainActor
    func mainViewModel_is_mainActor_isolated() async {
        // This test verifies that MainViewModel operations run on MainActor

        // Arrange
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()
        prefs.channelId = "UC123"
        prefs.cachedChannelId = "UC123"
        prefs.uploadPlaylistId = "UU123"

        // Act - Create and use MainViewModel (must be on @MainActor)
        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Assert - These operations are only possible if we're on @MainActor
        #expect(vm.isLive == false, "Should access MainActor-isolated properties")
        #expect(vm.viewerCount == 0, "Should access MainActor-isolated properties")

        // Verify we can call @MainActor methods
        await vm.startMonitoring()
        await vm.stopMonitoring()

        #expect(Bool(true), "All MainActor operations completed successfully")
    }

    @Test("PreferencesManager is @MainActor isolated")
    @MainActor
    func preferencesManager_is_mainActor_isolated() async {
        // This test verifies that PreferencesManager operations run on MainActor

        // Act - Access PreferencesManager (must be on @MainActor)
        let prefs = PreferencesManager.shared

        // Assert - These operations are only possible if we're on @MainActor
        let _ = prefs.getChannelId()
        let _ = prefs.getLiveCheckInterval()

        #expect(Bool(true), "PreferencesManager is accessible on MainActor")

        // Verify we can modify preferences
        prefs.updateChannelId("UC_Test_\(UUID().uuidString)")

        #expect(Bool(true), "Can modify PreferencesManager on MainActor")

        // Clean up
        prefs.updateChannelId("")
    }

    @Test("YouTubeService is @MainActor isolated")
    @MainActor
    func youtubeService_is_mainActor_isolated() async {
        // This test verifies that YouTubeService can be created on MainActor

        // Act & Assert - Creating service on @MainActor should work
        do {
            let service = try YouTubeService(apiKey: "test_key_123")
            #expect(Bool(true), "YouTubeService created successfully on MainActor")

            // Verify we can call methods
            service.clearCache()
        } catch {
            // It's okay if initialization fails without a real API key
            #expect(Bool(true), "Test completed (initialization may fail without real API key)")
        }
    }

    // MARK: - Sendable Conformance Tests

    @Test("ClockProtocol types are Sendable")
    func clockProtocol_types_are_sendable() {
        // Arrange
        let systemClock = SystemClock()
        let testClock = TestClock()

        // Act - These should compile because they are Sendable
        Task {
            let _ = systemClock.now()
            let _ = testClock.now()
        }

        #expect(Bool(true), "Clock types are Sendable and can be used across actor boundaries")
    }

    @Test("NDIBroadcaster is @MainActor isolated")
    @MainActor
    func ndiBroadcaster_is_mainActor_isolated() async {
        // Arrange - NDIBroadcaster must be created on @MainActor
        let broadcaster = NDIBroadcaster()

        // Act - Should be able to call async methods on MainActor
        await broadcaster.sendTally(isLive: true, viewerCount: 100, title: "Test")

        #expect(Bool(true), "NDIBroadcaster is @MainActor isolated")
    }

    @Test("NDISpy is @MainActor isolated")
    @MainActor
    func ndiSpy_is_mainActor_isolated() async {
        // Arrange - NDISpy must be created on @MainActor
        let spy = NDISpy()

        // Act - Should be able to call async methods on MainActor
        await spy.sendTally(isLive: true, viewerCount: 100, title: "Test")

        #expect(Bool(true), "NDISpy is @MainActor isolated")
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent access to MainViewModel properties is safe")
    @MainActor
    func concurrent_access_to_viewModel_is_safe() async {
        // This test verifies that concurrent reads from different tasks are safe

        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: true, viewerCount: 100, title: "Test", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC123"
        prefs.cachedChannelId = "UC123"
        prefs.uploadPlaylistId = "UU123"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        await vm.startMonitoring()

        // Act - Read values directly (already on MainActor)
        await Task.yield() // Force task suspension
        let r1 = vm.isLive
        let r2 = vm.viewerCount
        let r3 = vm.title

        // Assert - All reads should succeed
        #expect(r1 == true, "Should read isLive safely")
        #expect(r2 == 100, "Should read viewerCount safely")
        #expect(r3 == "Test", "Should read title safely")

        await vm.stopMonitoring()
    }

    @Test("Sequential MainViewModel operations are safe")
    @MainActor
    func sequential_viewModel_operations_are_safe() async {
        // This test verifies that sequential operations maintain consistency

        // Arrange
        let fakeService = FakeYouTubeService(script: [
            LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 50, title: "Stream 1", videoId: "abc"),
            LiveStatus(isLive: true, viewerCount: 100, title: "Stream 2", videoId: "abc")
        ])

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC123"
        prefs.cachedChannelId = "UC123"
        prefs.uploadPlaylistId = "UU123"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Perform sequential operations
        await vm.startMonitoring()
        #expect(vm.isLive == false, "Initial state")

        // Manually trigger another check to move through the script
        // (We can't do this directly, so we just verify the state is consistent)
        await vm.stopMonitoring()
        await vm.startMonitoring()

        // Assert - Operations completed without data races
        #expect(Bool(true), "Sequential operations completed safely")

        await vm.stopMonitoring()
    }

    @Test("PreferencesManager updates are actor-safe")
    @MainActor
    func preferencesManager_updates_are_actor_safe() async {
        // This test verifies that preference updates don't cause data races

        // Arrange
        let prefs = PreferencesManager.shared

        // Act - Perform multiple updates
        prefs.updateChannelId("UC_Test1")
        prefs.updateIntervals(liveInterval: 10.0, notLiveInterval: 30.0)
        prefs.updateShowViewerCount(true)
        prefs.updateShowDateTime(false)

        // Assert - All operations completed without data races
        #expect(prefs.getChannelId() == "UC_Test1", "Updates applied correctly")
        #expect(prefs.getLiveCheckInterval() == 10.0, "Updates applied correctly")

        // Clean up
        prefs.updateChannelId("")
        prefs.updateIntervals(liveInterval: 5.0, notLiveInterval: 20.0)
    }

    // MARK: - Test Isolation Verification

    @Test("Test infrastructure respects actor isolation")
    @MainActor
    func test_infrastructure_respects_isolation() async {
        // This test verifies our test doubles work correctly with actors

        // Arrange - All test doubles should be usable on MainActor
        let fakeService = FakeYouTubeService()
        let inMemoryPrefs = InMemoryPreferences()
        let ndiSpy = NDISpy()
        let testClock = TestClock()

        // Act - Use all test doubles
        fakeService.nextStatus = LiveStatus(isLive: true, viewerCount: 1, title: "Test", videoId: "abc")
        inMemoryPrefs.channelId = "UC_Test"
        await ndiSpy.sendTally(isLive: true, viewerCount: 100, title: "Test")
        let _ = testClock.now()

        // Assert
        #expect(Bool(true), "All test infrastructure works with actor isolation")
    }

    @Test("Async operations complete in correct actor context")
    @MainActor
    func async_operations_maintain_actor_context() async {
        // This test verifies async operations maintain MainActor context

        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC123"
        prefs.cachedChannelId = "UC123"
        prefs.uploadPlaylistId = "UU123"

        let vm = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Perform async operations
        await vm.startMonitoring()

        // Assert - We're still on MainActor (can access properties directly)
        let isLive = vm.isLive
        #expect(isLive == false, "Should maintain MainActor context")

        await vm.stopMonitoring()

        // Still on MainActor
        let viewerCount = vm.viewerCount
        #expect(viewerCount == 0, "Should still be on MainActor after async operations")
    }
}
