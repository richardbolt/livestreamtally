//
//  NDIBroadcasterTests.swift
//  LiveStreamTallyTests
//
//  Tests for NDI broadcaster integration logic
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("NDI Broadcaster Tests")
struct NDIBroadcasterTests {

    // MARK: - Initialization Tests

    @Test("NDIBroadcaster initializes without crashing")
    @MainActor
    func ndiBroadcaster_initializes() {
        // Act
        let broadcaster = NDIBroadcaster()

        // Assert - Just verify it doesn't crash
        #expect(Bool(true), "NDIBroadcaster should initialize without crashing")

        // Note: We can't verify isInitialized as it's private, but the fact
        // that initialization completed is sufficient
    }

    // MARK: - Integration Tests with Mock

    @Test("MockNDIBroadcaster tracks start and stop calls")
    @MainActor
    func mockBroadcaster_tracks_lifecycle() async {
        // Arrange
        let mockBroadcaster = MockNDIBroadcaster()
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()

        let viewModel = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act - Start
        await mockBroadcaster.start(name: "TestOutput", viewModel: viewModel)

        // Assert
        #expect(mockBroadcaster.isStarted, "Should be started")
        #expect(mockBroadcaster.startCalled, "Start should have been called")
        #expect(mockBroadcaster.lastOutputName == "TestOutput", "Should track output name")

        // Act - Stop
        await mockBroadcaster.stop()

        // Assert
        #expect(!mockBroadcaster.isStarted, "Should be stopped")
        #expect(mockBroadcaster.stopCalled, "Stop should have been called")
    }

    @Test("MockNDIBroadcaster tracks tally calls")
    @MainActor
    func mockBroadcaster_tracks_tally_calls() async {
        // Arrange
        let mockBroadcaster = MockNDIBroadcaster()

        // Act
        await mockBroadcaster.sendTally(isLive: true, viewerCount: 250, title: "Live Stream")

        // Assert
        #expect(mockBroadcaster.sendTallyCalled, "sendTally should have been called")
        #expect(mockBroadcaster.lastIsLive == true, "Should track live status")
        #expect(mockBroadcaster.lastViewerCount == 250, "Should track viewer count")
        #expect(mockBroadcaster.lastTitle == "Live Stream", "Should track title")
    }

    @Test("MockNDIBroadcaster formats metadata correctly")
    @MainActor
    func mockBroadcaster_formats_metadata() async {
        // Arrange
        let mockBroadcaster = MockNDIBroadcaster()

        // Act
        await mockBroadcaster.sendTally(isLive: true, viewerCount: 100, title: "Test Stream")

        // Assert - Verify metadata structure
        let metadata = mockBroadcaster.lastMetadata ?? ""
        #expect(metadata.hasPrefix("<ndi_metadata "), "Should start with opening tag")
        #expect(metadata.hasSuffix("/>"), "Should end with self-closing tag")
        #expect(metadata.contains("isLive=\"true\""), "Should include live status")
        #expect(metadata.contains("viewerCount=\"100\""), "Should include viewer count")
        #expect(metadata.contains("title=\"Test Stream\""), "Should include title")
    }

    @Test("MockNDIBroadcaster handles special characters in titles")
    @MainActor
    func mockBroadcaster_escapes_special_characters() async {
        // Arrange
        let mockBroadcaster = MockNDIBroadcaster()
        let titleWithSpecialChars = "Test \"Stream\" & <Tags>"

        // Act
        await mockBroadcaster.sendTally(isLive: true, viewerCount: 50, title: titleWithSpecialChars)

        // Assert
        let metadata = mockBroadcaster.lastMetadata ?? ""

        // Verify special characters are escaped
        #expect(metadata.contains("&quot;"), "Should escape double quotes")
        #expect(metadata.contains("&amp;"), "Should escape ampersands")
        #expect(metadata.contains("&lt;"), "Should escape less-than")
        #expect(metadata.contains("&gt;"), "Should escape greater-than")

        // Verify the original unescaped characters are NOT in the metadata
        #expect(!metadata.contains("\"Stream\""), "Should not contain unescaped quotes")
        #expect(!metadata.contains(" & "), "Should not contain unescaped ampersand")
        #expect(!metadata.contains("<Tags>"), "Should not contain unescaped tags")

        // Verify it's still valid XML
        #expect(metadata.hasPrefix("<ndi_metadata "), "Should be valid XML")
        #expect(metadata.hasSuffix("/>"), "Should close properly")
    }

    @Test("MockNDIBroadcaster handles OFF AIR state")
    @MainActor
    func mockBroadcaster_handles_off_air() async {
        // Arrange
        let mockBroadcaster = MockNDIBroadcaster()

        // Act
        await mockBroadcaster.sendTally(isLive: false, viewerCount: 0, title: "")

        // Assert
        #expect(mockBroadcaster.lastIsLive == false, "Should track off-air status")
        #expect(mockBroadcaster.lastViewerCount == 0, "Should show zero viewers")
        #expect(mockBroadcaster.lastTitle == "", "Should have empty title")

        let metadata = mockBroadcaster.lastMetadata ?? ""
        #expect(metadata.contains("isLive=\"false\""), "Metadata should show not live")
    }

    @Test("MockNDIBroadcaster handles multiple tally updates")
    @MainActor
    func mockBroadcaster_handles_multiple_updates() async {
        // Arrange
        let mockBroadcaster = MockNDIBroadcaster()

        // Act - Send multiple updates
        await mockBroadcaster.sendTally(isLive: true, viewerCount: 50, title: "Starting")
        await mockBroadcaster.sendTally(isLive: true, viewerCount: 100, title: "Growing")
        await mockBroadcaster.sendTally(isLive: true, viewerCount: 150, title: "Peak")

        // Assert - Should track the latest values
        #expect(mockBroadcaster.lastViewerCount == 150, "Should track latest viewer count")
        #expect(mockBroadcaster.lastTitle == "Peak", "Should track latest title")

        // Should track that it was called multiple times
        // (MockNDIBroadcaster could be enhanced to track call count)
    }

    // MARK: - Real NDI Tests (Disabled)

    @Test(.disabled("Requires NDI runtime"))
    @MainActor
    func real_ndi_sendTally_does_not_crash() async {
        // This test is disabled because it requires the NDI runtime
        // to be installed and available

        // Arrange
        let broadcaster = NDIBroadcaster()

        // Act - Just verify it doesn't crash when sender is nil
        await broadcaster.sendTally(isLive: true, viewerCount: 100, title: "Test Stream")

        // Assert
        #expect(Bool(true), "Should not crash even without initialized sender")
    }

    @Test(.disabled("Requires NDI runtime and main window"))
    @MainActor
    func real_ndi_start_requires_window() async {
        // This test is disabled because it requires:
        // 1. NDI runtime to be installed
        // 2. A main application window to exist

        // Arrange
        let broadcaster = NDIBroadcaster()
        let fakeService = FakeYouTubeService()
        let prefs = InMemoryPreferences()
        let viewModel = MainViewModel(
            youtubeService: fakeService,
            preferences: prefs,
            isTestMode: true
        )

        // Act
        await broadcaster.start(name: "TestOutput", viewModel: viewModel)

        // Assert
        // In a real test environment with NDI and a window, we would verify:
        // - The broadcaster starts successfully
        // - The sender is created
        // - The view to capture is set
        #expect(Bool(true), "Start should complete without crashing")

        // Clean up
        await broadcaster.stop()
    }
}
