//
//  YouTubeServiceProtocol.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation

/// Protocol for YouTube service to enable dependency injection and testing
@MainActor
protocol YouTubeServiceProtocol {
    /// Resolves a channel identifier (ID, @handle, or handle) to a channel ID and upload playlist ID
    /// - Parameter identifier: The channel identifier to resolve
    /// - Returns: A tuple of (channelId, uploadPlaylistId)
    /// - Throws: YouTubeError if the identifier cannot be resolved
    func resolveChannelIdentifier(_ identifier: String) async throws -> (String, String)

    /// Checks the live status of a channel
    /// - Parameters:
    ///   - channelId: The YouTube channel ID
    ///   - uploadPlaylistId: The upload playlist ID for the channel
    /// - Returns: The current live status
    /// - Throws: YouTubeError if the status cannot be determined
    func checkLiveStatus(channelId: String, uploadPlaylistId: String) async throws -> LiveStatus

    /// Clears the cached video ID
    func clearCache()
}
