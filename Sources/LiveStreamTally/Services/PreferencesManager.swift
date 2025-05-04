//
//  PreferencesManager.swift
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
import os

@MainActor
class PreferencesManager {
    static let shared = PreferencesManager()
    
    // MARK: - Preference Keys (Static Constants)
    
    struct Keys {
        static let channelId = "youtube_channel_id"
        static let cachedChannelId = "youtube_channel_id_cached"
        static let uploadPlaylistId = "youtube_upload_playlist_id"
        static let liveCheckInterval = "youtube_live_check_interval"
        static let notLiveCheckInterval = "youtube_not_live_check_interval"
    }
    
    // MARK: - Notification Names
    
    struct NotificationNames {
        static let channelChanged = Notification.Name("com.richardbolt.livestreamtally.preferences.channelChanged")
        static let apiKeyChanged = Notification.Name("com.richardbolt.livestreamtally.preferences.apiKeyChanged")
        static let resolvedChannelChanged = Notification.Name("com.richardbolt.livestreamtally.preferences.resolvedChannelChanged")
        static let intervalChanged = Notification.Name("com.richardbolt.livestreamtally.preferences.intervalChanged")
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var channelId: String
    @Published private(set) var cachedChannelId: String
    @Published private(set) var uploadPlaylistId: String
    @Published private(set) var liveCheckInterval: TimeInterval
    @Published private(set) var notLiveCheckInterval: TimeInterval
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        // Load initial values from UserDefaults
        channelId = defaults.string(forKey: Keys.channelId) ?? ""
        cachedChannelId = defaults.string(forKey: Keys.cachedChannelId) ?? ""
        uploadPlaylistId = defaults.string(forKey: Keys.uploadPlaylistId) ?? ""
        liveCheckInterval = defaults.double(forKey: Keys.liveCheckInterval).nonZero ?? 30.0
        notLiveCheckInterval = defaults.double(forKey: Keys.notLiveCheckInterval).nonZero ?? 60.0
        
        // Set up observation for external changes to UserDefaults
        setupObservations()
        
        Logger.debug("PreferencesManager initialized with channelId: \(channelId), cachedChannelId: \(cachedChannelId), uploadPlaylistId: \(uploadPlaylistId), liveCheckInterval: \(liveCheckInterval), notLiveCheckInterval: \(notLiveCheckInterval)", category: .app)
    }
    
    // MARK: - Public Methods
    
    // Channel ID methods
    func getChannelId() -> String {
        return channelId
    }
    
    func updateChannelId(_ newValue: String) {
        Logger.debug("Updating channelId to: \(newValue)", category: .app)
        
        // Update UserDefaults
        defaults.set(newValue, forKey: Keys.channelId)
        
        // Clear cached values when channel ID changes
        clearChannelCache()
        
        // Update published property
        channelId = newValue
        
        // Notify observers
        postNotification(name: NotificationNames.channelChanged)
    }
    
    func clearChannelCache() {
        Logger.debug("Clearing channel cache", category: .app)
        
        // Clear cached channel ID and playlist ID
        defaults.removeObject(forKey: Keys.cachedChannelId)
        defaults.removeObject(forKey: Keys.uploadPlaylistId)
        
        // Update published properties
        cachedChannelId = ""
        uploadPlaylistId = ""
    }
    
    // Method to set resolved channel info
    func setResolvedChannelInfo(channelId: String, playlistId: String) {
        Logger.debug("Setting resolved channel info - channelId: \(channelId), playlistId: \(playlistId)", category: .app)
        
        // Update UserDefaults
        defaults.set(channelId, forKey: Keys.cachedChannelId)
        defaults.set(playlistId, forKey: Keys.uploadPlaylistId)
        
        // Update published properties
        cachedChannelId = channelId
        uploadPlaylistId = playlistId
        
        // Notify observers
        postNotification(name: NotificationNames.resolvedChannelChanged)
    }
    
    // API Key methods (delegating to KeychainManager)
    func getApiKey() -> String? {
        return KeychainManager.shared.retrieveAPIKey()
    }
    
    func updateApiKey(_ newValue: String) -> Bool {
        Logger.debug("updateApiKey called with new value", category: .app)
        
        let success = KeychainManager.shared.saveAPIKey(newValue)
        
        if success {
            // Notify observers if save was successful
            Logger.debug("About to post apiKeyChanged notification", category: .app)
            postNotification(name: NotificationNames.apiKeyChanged)
        }
        
        return success
    }
    
    // Polling interval methods
    func getLiveCheckInterval() -> TimeInterval {
        return liveCheckInterval
    }
    
    func getNotLiveCheckInterval() -> TimeInterval {
        return notLiveCheckInterval
    }
    
    func updateIntervals(liveInterval: TimeInterval, notLiveInterval: TimeInterval) {
        Logger.debug("Updating intervals - live: \(liveInterval), notLive: \(notLiveInterval)", category: .app)
        
        // Update UserDefaults
        defaults.set(liveInterval, forKey: Keys.liveCheckInterval)
        defaults.set(notLiveInterval, forKey: Keys.notLiveCheckInterval)
        
        // Update published properties
        liveCheckInterval = liveInterval
        notLiveCheckInterval = notLiveInterval
        
        // Notify observers
        postNotification(name: NotificationNames.intervalChanged)
    }
    
    // MARK: - Private Methods
    
    private func setupObservations() {
        // Observe external changes to UserDefaults
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // Check which keys have changed and update published properties
        let newChannelId = defaults.string(forKey: Keys.channelId) ?? ""
        if newChannelId != channelId {
            channelId = newChannelId
        }
        
        let newCachedChannelId = defaults.string(forKey: Keys.cachedChannelId) ?? ""
        if newCachedChannelId != cachedChannelId {
            cachedChannelId = newCachedChannelId
        }
        
        let newUploadPlaylistId = defaults.string(forKey: Keys.uploadPlaylistId) ?? ""
        if newUploadPlaylistId != uploadPlaylistId {
            uploadPlaylistId = newUploadPlaylistId
        }
        
        let newLiveCheckInterval = defaults.double(forKey: Keys.liveCheckInterval).nonZero ?? 30.0
        if newLiveCheckInterval != liveCheckInterval {
            liveCheckInterval = newLiveCheckInterval
        }
        
        let newNotLiveCheckInterval = defaults.double(forKey: Keys.notLiveCheckInterval).nonZero ?? 60.0
        if newNotLiveCheckInterval != notLiveCheckInterval {
            notLiveCheckInterval = newNotLiveCheckInterval
        }
    }
    
    private func postNotification(name: Notification.Name, userInfo: [AnyHashable: Any]? = nil) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: Date())
        
        if name == NotificationNames.apiKeyChanged {
            Logger.debug("POSTING apiKeyChanged notification at \(timestamp)", category: .app)
        }
        
        NotificationCenter.default.post(
            name: name,
            object: self,
            userInfo: userInfo
        )
    }
}

// MARK: - Double Extension
extension Double {
    /// Returns nil if the value is zero, otherwise returns the value.
    /// Useful for UserDefaults where 0.0 is returned for missing keys.
    var nonZero: Double? {
        return self == 0.0 ? nil : self
    }
} 