//
//  InMemoryPreferences.swift
//  LiveStreamTallyTests
//
//  Test infrastructure for isolated preference testing
//

import Foundation
@testable import LiveStreamTally

/// In-memory preferences manager for testing
/// Provides isolated preference storage that doesn't affect UserDefaults
@MainActor
final class InMemoryPreferences: PreferencesManagerProtocol {
    // Published properties (not actually @Published in test double, but accessible)
    var channelId: String = ""
    var cachedChannelId: String = ""
    var uploadPlaylistId: String = ""
    var liveCheckInterval: TimeInterval = 5.0
    var notLiveCheckInterval: TimeInterval = 20.0
    var showViewerCount: Bool = true
    var showDateTime: Bool = true

    // Internal storage
    private var apiKey: String? = nil

    init() {}

    // MARK: - Channel Management

    func getChannelId() -> String {
        return channelId
    }

    func updateChannelId(_ newValue: String) {
        channelId = newValue
        // Clear cached values when channel changes
        clearChannelCache()
        // Post notification
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.channelChanged,
            object: self
        )
    }

    func clearChannelCache() {
        cachedChannelId = ""
        uploadPlaylistId = ""
    }

    func setResolvedChannelInfo(channelId: String, playlistId: String) {
        cachedChannelId = channelId
        uploadPlaylistId = playlistId
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.resolvedChannelChanged,
            object: self
        )
    }

    // MARK: - API Key Management

    func getApiKey() -> String? {
        return apiKey
    }

    func updateApiKey(_ newValue: String) -> Bool {
        apiKey = newValue
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.apiKeyChanged,
            object: self
        )
        return true
    }

    // MARK: - Polling Interval Management

    func getLiveCheckInterval() -> TimeInterval {
        return liveCheckInterval
    }

    func getNotLiveCheckInterval() -> TimeInterval {
        return notLiveCheckInterval
    }

    func updateIntervals(liveInterval: TimeInterval, notLiveInterval: TimeInterval) {
        liveCheckInterval = liveInterval
        notLiveCheckInterval = notLiveInterval
        NotificationCenter.default.post(
            name: PreferencesManager.NotificationNames.intervalChanged,
            object: self
        )
    }

    // MARK: - Display Preferences

    func getShowViewerCount() -> Bool {
        return showViewerCount
    }

    func updateShowViewerCount(_ show: Bool) {
        showViewerCount = show
    }

    func getShowDateTime() -> Bool {
        return showDateTime
    }

    func updateShowDateTime(_ show: Bool) {
        showDateTime = show
    }
}
