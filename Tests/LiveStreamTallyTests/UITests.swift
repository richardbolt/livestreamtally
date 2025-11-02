//
//  UITests.swift
//  LiveStreamTallyTests
//
//  Smoke tests for UI components
//

import Testing
import SwiftUI
import Foundation
@testable import LiveStreamTally

@Suite("UI Tests")
struct UITests {

    // MARK: - Smoke Tests

    @Test("ContentView initializes without crashing")
    @MainActor
    func contentView_initializes() async throws {
        // This is a smoke test to ensure the view can be created

        // Act
        let _ = ContentView()

        // Assert
        #expect(Bool(true), "ContentView should initialize without crashing")
    }

    @Test("SettingsViewModel initializes correctly")
    @MainActor
    func settingsViewModel_initializes() async {
        // Act
        let settingsViewModel = SettingsViewModel()

        // Assert - Initial state
        #expect(!settingsViewModel.isProcessing, "Should not be processing initially")
        #expect(settingsViewModel.channelError == nil, "Should have no channel error initially")
        #expect(settingsViewModel.apiKeyError == nil, "Should have no API key error initially")
    }

    @Test("NDIViewModel initializes with MainViewModel")
    @MainActor
    func ndiViewModel_initializes() async {
        // Arrange
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()
        let mainViewModel = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        let ndiViewModel = NDIViewModel(mainViewModel: mainViewModel)

        // Assert
        #expect(!ndiViewModel.isStreaming, "Should not be streaming initially")
    }

    @Test("MainViewModel time format is correct")
    @MainActor
    func mainViewModel_time_format_is_correct() async {
        // This test verifies the time display functionality works

        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let viewModel = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        await viewModel.startMonitoring()
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Assert
        #expect(!viewModel.currentTime.isEmpty, "Time should be set")

        // Verify time format: h:mm:ss AM/PM
        let timePattern = /^\d{1,2}:\d{2}:\d{2} (AM|PM)$/
        #expect(viewModel.currentTime.contains(timePattern), "Time should match format 'h:mm:ss AM/PM'")

        // Cleanup
        await viewModel.stopMonitoring()
    }

    // MARK: - Integration Smoke Tests

    @Test("MainViewModel lifecycle operations don't crash")
    @MainActor
    func mainViewModel_lifecycle_doesnt_crash() async {
        // Arrange
        let fakeService = FakeYouTubeService()
        fakeService.nextStatus = LiveStatus(isLive: true, viewerCount: 100, title: "Test", videoId: "abc")

        let prefs = InMemoryPreferences()
        prefs.channelId = "UC12345"
        prefs.cachedChannelId = "UC12345"
        prefs.uploadPlaylistId = "UU12345"

        let viewModel = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Perform typical lifecycle operations
        await viewModel.startMonitoring()
        await viewModel.stopMonitoring()
        viewModel.updateChannelId("UC_NewChannel")
        viewModel.updateApiKey("new_test_key")

        // Assert
        #expect(Bool(true), "Lifecycle operations should complete without crashing")
    }

    @Test("SettingsViewModel initialization doesn't crash")
    @MainActor
    func settingsViewModel_lifecycle_doesnt_crash() async {
        // This test verifies basic settings lifecycle operations work

        // Arrange
        let settingsViewModel = SettingsViewModel()

        // Act - Call available methods
        // SettingsViewModel properties are private/readonly, so we just verify
        // that the view model exists and can be used

        // Assert - Just verify initialization completed
        #expect(Bool(true), "SettingsViewModel lifecycle operations should complete without crashing")
    }

    // Note: Removed trivial tests that don't test actual app code:
    // - testViewerCountFormatting (tested local helper function, not app code)
    // - testLiveStateHandling (just set and get properties)
    // - testStatusTextDisplay (tested local helper function)
    // - testChannelInfoDisplay (tested mock class, not app code)
    // - testStatusIndicatorColor (tested local helper function)
    // - testMonitoring (trivial start/stop with no verification)
    // - testUpdatingSettings (trivial method calls with no verification)

    // For comprehensive UI testing, consider:
    // - ViewInspector for testing SwiftUI view hierarchy
    // - Snapshot testing for visual regression testing
    // - XCUITest for end-to-end UI testing
}
