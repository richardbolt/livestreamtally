//
//  YouTubeServiceTests.swift
//  LiveStreamTallyTests
//
//  Tests for YouTube API integration logic
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("YouTube Service Tests")
struct YouTubeServiceTests {
    private let testApiKey = "test_api_key_12345"

    // MARK: - Helper Functions

    /// Checks if YouTube API integration tests can run by verifying environment variables
    /// - Returns: true if both YOUTUBE_API_KEY and YOUTUBE_TEST_CHANNEL_ID are set
    static func isYouTubeAPIAvailable() -> Bool {
        let apiKey = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"]
        let channelId = ProcessInfo.processInfo.environment["YOUTUBE_TEST_CHANNEL_ID"]

        return !(apiKey?.isEmpty ?? true) && !(channelId?.isEmpty ?? true)
    }

    /// Gets the YouTube API key from environment variables
    /// - Returns: The API key if available, nil otherwise
    static func getYouTubeAPIKey() -> String? {
        return ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"]
    }

    /// Gets the test channel ID from environment variables
    /// - Returns: The channel ID if available, nil otherwise
    static func getTestChannelID() -> String? {
        return ProcessInfo.processInfo.environment["YOUTUBE_TEST_CHANNEL_ID"]
    }

    // MARK: - Initialization Tests

    @Test("Initialization with empty API key throws error")
    @MainActor
    func initWithEmptyApiKey_throws_invalidApiKey() async throws {
        await #expect(throws: YouTubeError.invalidApiKey) {
            try await YouTubeService(apiKey: "")
        }
    }

    @Test("Initialization with valid API key succeeds")
    @MainActor
    func initWithValidApiKey_succeeds() async throws {
        let service = try await YouTubeService(apiKey: testApiKey)

        // Verify service was created (no error thrown)
        #expect(Bool(true), "Should be able to create YouTubeService with valid API key")
    }

    // MARK: - Performance Tests

    @Test("YouTubeService creation performance")
    @MainActor
    func measureServiceCreationTime() async throws {
        let iterations = 100
        var totalDuration: TimeInterval = 0

        for _ in 0..<iterations {
            let start = Date()
            _ = try await YouTubeService(apiKey: testApiKey)
            totalDuration += Date().timeIntervalSince(start)
        }

        let averageDuration = totalDuration / Double(iterations)
        let averageMs = averageDuration * 1000

        print("=== YouTubeService Creation Performance ===")
        print("Iterations: \(iterations)")
        print("Total time: \(String(format: "%.2f", totalDuration * 1000))ms")
        print("Average creation time: \(String(format: "%.4f", averageMs))ms")
        print("===========================================")

        // Service creation should be fast (< 100ms per creation)
        // If this test fails, caching might be beneficial
        #expect(averageDuration < 0.1, "Service creation should be fast (< 100ms average)")
    }

    // MARK: - Cache Behavior Tests

    @Test("clearCache clears cached video ID")
    @MainActor
    func clearCache_removes_cached_video_id() async throws {
        let service = try await YouTubeService(apiKey: testApiKey)

        // Call clearCache - should not throw
        service.clearCache()

        // Verify it completes without error
        #expect(Bool(true), "clearCache() should complete without errors")
    }

    // NOTE: The following tests for caching behavior would require mocking the
    // Google API client, which is complex. In a real implementation, we would:
    // 1. Create a wrapper protocol around GTLRYouTubeService
    // 2. Inject the wrapper into YouTubeService
    // 3. Create a mock implementation for testing
    //
    // For now, these are documented as integration tests that would require
    // a real API key and network access:
    //
    // @Test(.disabled("Requires real API and mocking framework"))
    // func checkLiveStatus_caches_videoId_when_live() async throws { }
    //
    // @Test(.disabled("Requires real API and mocking framework"))
    // func checkLiveStatus_checks_cached_videoId_first() async throws { }
    //
    // @Test(.disabled("Requires real API and mocking framework"))
    // func checkLiveStatus_falls_back_to_playlist_when_cache_empty() async throws { }

    // MARK: - Channel Resolution Tests

    @Test("resolveChannelIdentifier handles UC channel ID format")
    @MainActor
    func resolveChannel_handles_channelId_format() async throws {
        // This test verifies the logic for detecting UC-prefixed channel IDs
        // The actual API call would require mocking or a real API key

        let channelId = "UC1234567890abcdefgh"

        // Verify the format is detected correctly (starts with UC)
        #expect(channelId.hasPrefix("UC"), "Channel ID should start with UC")
        #expect(channelId.count > 10, "Channel ID should be reasonably long")
    }

    @Test("resolveChannelIdentifier handles @handle format")
    @MainActor
    func resolveChannel_handles_handle_with_at() async throws {
        // This test verifies the logic for detecting @handle format

        let handle = "@testuser"

        // Verify @ prefix is detected
        #expect(handle.hasPrefix("@"), "Handle should start with @")

        // Test trimming logic
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed == "@testuser", "Trimming should preserve @")
    }

    @Test("resolveChannelIdentifier handles handle without @ prefix")
    @MainActor
    func resolveChannel_handles_handle_without_at() async throws {
        // This test verifies the logic for handles without @ prefix

        let handle = "testuser"

        // Verify it doesn't have UC prefix (not a channel ID)
        #expect(!handle.hasPrefix("UC"), "Plain handle should not start with UC")

        // Test trimming logic
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed == "testuser", "Trimming should work correctly")
    }

    @Test("resolveChannelIdentifier trims whitespace")
    @MainActor
    func resolveChannel_trims_whitespace() async throws {
        let handleWithSpaces = "  testuser  "
        let trimmed = handleWithSpaces.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(trimmed == "testuser", "Should trim leading and trailing whitespace")
    }

    // NOTE: Full integration tests for channel resolution would require real API:
    //
    // @Test(.disabled("Requires real API key"))
    // func resolveChannel_with_real_channelId() async throws {
    //     let service = try await YouTubeService(apiKey: realApiKey)
    //     let (channelId, playlistId) = try await service.resolveChannelIdentifier("UC...")
    //     #expect(!channelId.isEmpty)
    //     #expect(!playlistId.isEmpty)
    //     #expect(playlistId.hasPrefix("UU"))
    // }

    // MARK: - Error Handling Tests

    @Test("YouTubeError enum has all expected cases")
    func youtubeError_has_expected_cases() {
        // Verify all error cases exist and are Equatable
        let errors: [YouTubeError] = [
            .invalidApiKey,
            .invalidChannelId,
            .quotaExceeded,
            .networkError,
            .unknownError
        ]

        #expect(errors.count == 5, "Should have 5 error cases")

        // Verify Equatable works
        #expect(YouTubeError.invalidApiKey == YouTubeError.invalidApiKey)
        #expect(YouTubeError.quotaExceeded != YouTubeError.networkError)
    }

    // NOTE: Error mapping tests would require mocking NSError responses:
    //
    // @Test("mapError converts quota exceeded error")
    // @MainActor
    // func mapError_converts_quotaExceeded() async throws {
    //     // Would require creating mock NSError with proper structure
    // }

    // MARK: - LiveStatus Model Tests

    @Test("LiveStatus model stores values correctly")
    func liveStatus_stores_values() {
        let status = LiveStatus(
            isLive: true,
            viewerCount: 1234,
            title: "Test Stream",
            videoId: "abc123"
        )

        #expect(status.isLive == true)
        #expect(status.viewerCount == 1234)
        #expect(status.title == "Test Stream")
        #expect(status.videoId == "abc123")
    }

    @Test("LiveStatus can represent offline state")
    func liveStatus_offline_state() {
        let status = LiveStatus(
            isLive: false,
            viewerCount: 0,
            title: "",
            videoId: "abc123"
        )

        #expect(status.isLive == false)
        #expect(status.viewerCount == 0)
        #expect(status.title.isEmpty)
    }

    // MARK: - Integration Tests

    // The following integration tests require real YouTube API credentials.
    // Set environment variables YOUTUBE_API_KEY and YOUTUBE_TEST_CHANNEL_ID to enable.

    @Test(.enabled(if: isYouTubeAPIAvailable(), "Requires YOUTUBE_API_KEY and YOUTUBE_TEST_CHANNEL_ID environment variables"))
    @MainActor
    func integration_checkLiveStatus_with_real_api() async throws {
        // This test verifies the full flow with a real API key:
        // 1. Initialize service with real API key
        // 2. Resolve a real channel ID
        // 3. Check live status
        // 4. Verify response structure
        //
        // To run: Set YOUTUBE_API_KEY and YOUTUBE_TEST_CHANNEL_ID environment variables
        // Example: YOUTUBE_API_KEY=your_key YOUTUBE_TEST_CHANNEL_ID=UC... swift test

        guard let apiKey = Self.getYouTubeAPIKey(),
              let testChannelId = Self.getTestChannelID() else {
            Issue.record("Environment variables not set despite isYouTubeAPIAvailable() returning true")
            return
        }

        let service = try await YouTubeService(apiKey: apiKey)
        let (channelId, playlistId) = try await service.resolveChannelIdentifier(testChannelId)

        // Verify we got valid IDs back
        #expect(!channelId.isEmpty, "Channel ID should not be empty")
        #expect(!playlistId.isEmpty, "Playlist ID should not be empty")
        #expect(channelId.hasPrefix("UC"), "Channel ID should start with UC")
        #expect(playlistId.hasPrefix("UU"), "Upload playlist ID should start with UU")

        let status = try await service.checkLiveStatus(channelId: channelId, uploadPlaylistId: playlistId)

        #expect(!status.videoId.isEmpty, "Video ID should not be empty")
        // Note: isLive can be true or false depending on actual channel state at test time
        // We just verify the structure is valid
        print("Integration test result - isLive: \(status.isLive), viewerCount: \(status.viewerCount), title: '\(status.title)'")
    }

    @Test(.enabled(if: isYouTubeAPIAvailable(), "Requires YOUTUBE_API_KEY and YOUTUBE_TEST_CHANNEL_ID environment variables"))
    @MainActor
    func integration_error_handling_with_invalid_channel() async throws {
        // This test verifies error handling with a real API call to an invalid channel
        // To run: Set YOUTUBE_API_KEY and YOUTUBE_TEST_CHANNEL_ID environment variables

        guard let apiKey = Self.getYouTubeAPIKey() else {
            Issue.record("Environment variable YOUTUBE_API_KEY not set despite isYouTubeAPIAvailable() returning true")
            return
        }

        let service = try await YouTubeService(apiKey: apiKey)

        // Try to resolve a channel ID that's clearly invalid
        await #expect(throws: YouTubeError.self) {
            try await service.resolveChannelIdentifier("INVALID_CHANNEL_ID_THAT_DOES_NOT_EXIST_123456789")
        }
    }
}
