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
    }
    
    // MARK: - Notification Names
    
    struct Notifications {
        static let channelChanged = Notification.Name("com.livestreamtally.preferences.channelChanged")
        static let apiKeyChanged = Notification.Name("com.livestreamtally.preferences.apiKeyChanged")
        static let resolvedChannelChanged = Notification.Name("com.livestreamtally.preferences.resolvedChannelChanged")
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var channelId: String
    @Published private(set) var cachedChannelId: String
    @Published private(set) var uploadPlaylistId: String
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        // Load initial values from UserDefaults
        channelId = defaults.string(forKey: Keys.channelId) ?? ""
        cachedChannelId = defaults.string(forKey: Keys.cachedChannelId) ?? ""
        uploadPlaylistId = defaults.string(forKey: Keys.uploadPlaylistId) ?? ""
        
        // Set up observation for external changes to UserDefaults
        setupObservations()
        
        Logger.debug("PreferencesManager initialized with channelId: \(channelId), cachedChannelId: \(cachedChannelId), uploadPlaylistId: \(uploadPlaylistId)", category: .app)
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
        postNotification(name: Notifications.channelChanged)
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
        postNotification(name: Notifications.resolvedChannelChanged)
    }
    
    // API Key methods (delegating to KeychainManager)
    func getApiKey() -> String? {
        return KeychainManager.shared.retrieveAPIKey()
    }
    
    func updateApiKey(_ newValue: String) -> Bool {
        Logger.debug("Updating API key", category: .app)
        
        let success = KeychainManager.shared.saveAPIKey(newValue)
        
        if success {
            // Notify observers if save was successful
            postNotification(name: Notifications.apiKeyChanged)
        }
        
        return success
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
    }
    
    private func postNotification(name: Notification.Name, userInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(
            name: name,
            object: self,
            userInfo: userInfo
        )
    }
} 