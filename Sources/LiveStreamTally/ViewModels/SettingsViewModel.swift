//
//  SettingsViewModel.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import SwiftUI
import os

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var channelError: String?
    @Published var apiKeyError: String?
    @Published var isProcessing = false
    
    private var youtubeService: YouTubeService?
    
    init() {
        // Initialize YouTubeService if API key exists
        if let apiKey = PreferencesManager.shared.getApiKey(), !apiKey.isEmpty {
            do {
                self.youtubeService = try YouTubeService(apiKey: apiKey)
            } catch {
                self.apiKeyError = "Invalid API key"
            }
        }
    }
    
    func saveSettings(channelId: String, apiKey: String) async {
        // Clear previous errors
        channelError = nil
        apiKeyError = nil
        
        // Track processing state
        isProcessing = true
        defer { isProcessing = false }
        
        // Get current values for comparison
        let currentChannelId = PreferencesManager.shared.getChannelId()
        let currentApiKey = PreferencesManager.shared.getApiKey() ?? ""
        
        // Check what changed
        let channelIdChanged = channelId != currentChannelId
        let apiKeyChanged = apiKey != currentApiKey
        
        // If nothing changed, return early
        if !channelIdChanged && !apiKeyChanged {
            return
        }
        
        // Handle API key change first
        if apiKeyChanged {
            // Save the new API key
            if !PreferencesManager.shared.updateApiKey(apiKey) {
                apiKeyError = "Failed to save API key"
                return
            }
            
            // Try to initialize a new service with the API key
            do {
                youtubeService = try YouTubeService(apiKey: apiKey)
            } catch {
                apiKeyError = "Invalid API key: \(error.localizedDescription)"
                return
            }
        }
        
        // Handle channel ID change
        if channelIdChanged {
            // Update the channel ID
            PreferencesManager.shared.updateChannelId(channelId)
            
            // Try to resolve the channel ID if not empty
            if !channelId.isEmpty {
                await resolveChannelId(channelId)
            }
        }
    }
    
    private func resolveChannelId(_ channelId: String) async {
        guard let service = youtubeService else {
            channelError = "YouTube service not initialized"
            return
        }
        
        do {
            Logger.debug("Resolving channel ID: \(channelId)", category: .settings)
            
            // Try to resolve the channel ID
            let (resolvedId, playlistId) = try await service.resolveChannelIdentifier(channelId)
            
            Logger.debug("Successfully resolved channel ID: \(channelId) to \(resolvedId) with playlist \(playlistId)", category: .settings)
            
            // Update the resolved info in PreferencesManager
            PreferencesManager.shared.setResolvedChannelInfo(
                channelId: resolvedId,
                playlistId: playlistId
            )
        } catch {
            Logger.error("Failed to resolve channel: \(error.localizedDescription)", category: .settings)
            
            // Handle resolution error
            channelError = "Failed to resolve channel: \(error.localizedDescription)"
            
            // Clear any cached values
            PreferencesManager.shared.clearChannelCache()
        }
    }
} 