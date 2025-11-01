//
//  FakeYouTubeService.swift
//  LiveStreamTallyTests
//
//  Test infrastructure for YouTube service testing
//

import Foundation
@testable import LiveStreamTally

/// Fake YouTube service for testing with scripted responses
@MainActor
final class FakeYouTubeService: YouTubeServiceProtocol {
    /// Script of statuses to return on successive calls
    var script: [LiveStatus] = []

    /// Current index in the script
    private var scriptIndex: Int = 0

    /// Status to return on next call (overrides script)
    var nextStatus: LiveStatus?

    /// Error to throw on next call
    var nextError: Error?

    /// Resolved channel info to return
    var resolvedChannelInfo: (String, String) = ("UC12345", "UU12345")

    /// Tracks whether methods were called
    var checkLiveStatusCalled = false
    var resolveChannelIdentifierCalled = false
    var clearCacheCalled = false

    /// Captured arguments from last checkLiveStatus call
    var lastChannelId: String?
    var lastUploadPlaylistId: String?

    /// Captured argument from last resolveChannelIdentifier call
    var lastIdentifier: String?

    init(script: [LiveStatus] = []) {
        self.script = script
    }

    func resolveChannelIdentifier(_ identifier: String) async throws -> (String, String) {
        resolveChannelIdentifierCalled = true
        lastIdentifier = identifier

        if let error = nextError {
            nextError = nil
            throw error
        }

        return resolvedChannelInfo
    }

    func checkLiveStatus(channelId: String, uploadPlaylistId: String) async throws -> LiveStatus {
        checkLiveStatusCalled = true
        lastChannelId = channelId
        lastUploadPlaylistId = uploadPlaylistId

        if let error = nextError {
            nextError = nil
            throw error
        }

        if let status = nextStatus {
            nextStatus = nil
            return status
        }

        // Return from script
        if script.isEmpty {
            // Default: not live
            return LiveStatus(isLive: false, viewerCount: 0, title: "", videoId: "mock")
        }

        let status = script[scriptIndex]
        scriptIndex = min(scriptIndex + 1, script.count - 1)
        return status
    }

    func clearCache() {
        clearCacheCalled = true
    }

    /// Resets the script index to the beginning
    func resetScript() {
        scriptIndex = 0
    }
}
