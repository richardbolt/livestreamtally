//
//  PreferencesManagerProtocol.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import Combine

/// Protocol for preferences management to enable dependency injection and testing
@MainActor
protocol PreferencesManagerProtocol {
    // Published properties for reactive updates
    var channelId: String { get }
    var cachedChannelId: String { get }
    var uploadPlaylistId: String { get }
    var liveCheckInterval: TimeInterval { get }
    var notLiveCheckInterval: TimeInterval { get }
    var showViewerCount: Bool { get }
    var showDateTime: Bool { get }

    // Channel management
    func getChannelId() -> String
    func updateChannelId(_ newValue: String)
    func clearChannelCache()
    func setResolvedChannelInfo(channelId: String, playlistId: String)

    // API key management (delegates to KeychainManager)
    func getApiKey() -> String?
    func updateApiKey(_ newValue: String) -> Bool

    // Polling interval management
    func getLiveCheckInterval() -> TimeInterval
    func getNotLiveCheckInterval() -> TimeInterval
    func updateIntervals(liveInterval: TimeInterval, notLiveInterval: TimeInterval)

    // Display preferences
    func getShowViewerCount() -> Bool
    func updateShowViewerCount(_ show: Bool)
    func getShowDateTime() -> Bool
    func updateShowDateTime(_ show: Bool)
}
