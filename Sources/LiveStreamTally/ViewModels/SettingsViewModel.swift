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
    @Published var liveCheckInterval: TimeInterval
    @Published var notLiveCheckInterval: TimeInterval
    
    private var youtubeService: YouTubeService?
    
    init() {
        // Initialize with current values from PreferencesManager
        self.liveCheckInterval = PreferencesManager.shared.getLiveCheckInterval()
        self.notLiveCheckInterval = PreferencesManager.shared.getNotLiveCheckInterval()
        
        // Initialize YouTubeService if API key exists
        if let apiKey = PreferencesManager.shared.getApiKey(), !apiKey.isEmpty {
            do {
                self.youtubeService = try YouTubeService(apiKey: apiKey)
            } catch {
                self.apiKeyError = "Invalid API key"
            }
        }
    }
    
    // Add validation methods for the intervals
    func validateIntervals() -> Bool {
        // Ensure intervals are within reasonable bounds (5-300 seconds)
        let isLiveIntervalValid = liveCheckInterval >= 5 && liveCheckInterval <= 300
        let isNotLiveIntervalValid = notLiveCheckInterval >= 5 && notLiveCheckInterval <= 300
        
        return isLiveIntervalValid && isNotLiveIntervalValid
    }
    
    func saveSettings(channelId: String, apiKey: String) async {
        isProcessing = true
        
        // Save API key if it has changed
        let currentApiKey = PreferencesManager.shared.getApiKey() ?? ""
        if apiKey != currentApiKey {
            if !PreferencesManager.shared.updateApiKey(apiKey) {
                self.apiKeyError = "Failed to save API key"
                isProcessing = false
                return
            }
        }
        
        // Save channel ID if it has changed
        let currentChannelId = PreferencesManager.shared.getChannelId()
        if channelId != currentChannelId {
            PreferencesManager.shared.updateChannelId(channelId)
        }
        
        // Save intervals if they have changed and are valid
        if validateIntervals() {
            let currentLiveInterval = PreferencesManager.shared.getLiveCheckInterval()
            let currentNotLiveInterval = PreferencesManager.shared.getNotLiveCheckInterval()
            
            if liveCheckInterval != currentLiveInterval || notLiveCheckInterval != currentNotLiveInterval {
                PreferencesManager.shared.updateIntervals(
                    liveInterval: liveCheckInterval, 
                    notLiveInterval: notLiveCheckInterval
                )
            }
        }
        
        isProcessing = false
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