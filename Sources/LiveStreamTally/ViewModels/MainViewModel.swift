//
//  MainViewModel.swift
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
import Combine
import os

@MainActor
final class MainViewModel: ObservableObject {
    @Published var isLive = false {
        didSet {
            if oldValue != isLive {
                // Update timer interval when live status changes
                updateTimerInterval()
            }
        }
    }
    @Published var viewerCount = 0
    @Published var title = ""
    @Published var error: String?
    @Published var isLoading = false
    @Published var currentTime: String = ""
    
    // Remove @AppStorage properties
    // @AppStorage("youtube_channel_id") private var channelId = ""
    // @AppStorage("youtube_channel_id_cached") private var cachedChannelId = ""
    // @AppStorage("youtube_upload_playlist_id") private var uploadPlaylistId = ""
    
    // Add properties that will be updated from PreferencesManager
    private var channelId: String = ""
    private var cachedChannelId: String = ""
    private var uploadPlaylistId: String = ""
    
    private var youtubeService: YouTubeService?
    private var timer: Timer?
    private var timeTimer: Timer?
    
    // Timer intervals
    private let liveCheckInterval: TimeInterval = 30.0
    private let notLiveCheckInterval: TimeInterval = 60.0
    
    // Add cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(apiKey: String? = nil) {
        // Initialize with current values from PreferencesManager
        self.channelId = PreferencesManager.shared.getChannelId()
        self.cachedChannelId = PreferencesManager.shared.cachedChannelId
        self.uploadPlaylistId = PreferencesManager.shared.uploadPlaylistId
        
        // Initialize with provided API key or from PreferencesManager
        let keyToUse = apiKey ?? PreferencesManager.shared.getApiKey()
        
        if let keyToUse = keyToUse, !keyToUse.isEmpty {
            do {
                youtubeService = try YouTubeService(apiKey: keyToUse)
                self.error = nil
            } catch let serviceError {
                self.error = "Failed to initialize YouTube service: \(serviceError.localizedDescription)"
            }
        }
        
        // Setup subscriptions to PreferencesManager publishers
        setupPreferenceSubscriptions()
        
        // Register for notifications
        registerForNotifications()
    }
    
    deinit {
        // Unregister notifications
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupPreferenceSubscriptions() {
        // Subscribe to channelId changes
        PreferencesManager.shared.$channelId
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.channelId = newValue
            }
            .store(in: &cancellables)
        
        // Subscribe to cachedChannelId changes
        PreferencesManager.shared.$cachedChannelId
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.cachedChannelId = newValue
            }
            .store(in: &cancellables)
        
        // Subscribe to uploadPlaylistId changes
        PreferencesManager.shared.$uploadPlaylistId
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.uploadPlaylistId = newValue
            }
            .store(in: &cancellables)
    }
    
    private func registerForNotifications() {
        // Register for API key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApiKeyChanged),
            name: PreferencesManager.Notifications.apiKeyChanged,
            object: nil
        )
        
        // Register for channel ID changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChannelChanged),
            name: PreferencesManager.Notifications.channelChanged,
            object: nil
        )
    }
    
    @objc private func handleApiKeyChanged() {
        // Reinitialize YouTubeService with new API key
        if let apiKey = PreferencesManager.shared.getApiKey() {
            do {
                youtubeService = try YouTubeService(apiKey: apiKey)
                error = nil
            } catch let serviceError {
                error = "Failed to initialize YouTube service: \(serviceError.localizedDescription)"
            }
        }
    }
    
    @objc private func handleChannelChanged() {
        // Clear YouTube service cache when channel changes
        youtubeService?.clearCache()
        
        // Restart monitoring if active
        if timer != nil {
            stopMonitoring()
            startMonitoring()
        }
    }
    
    func getAPIKey() -> String? {
        return PreferencesManager.shared.getApiKey()
    }
    
    private func updateTimerInterval() {
        guard timer != nil else { return }
        
        // Stop existing timer
        timer?.invalidate()
        
        // Create new timer with appropriate interval
        timer = Timer.scheduledTimer(withTimeInterval: isLive ? liveCheckInterval : notLiveCheckInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkLiveStatus()
            }
        }
    }
    
    func startMonitoring() {
        Logger.debug("Monitoring timer started", category: .main)
        guard youtubeService != nil else {
            error = "YouTube service not initialized. Please check your API key."
            return
        }
        
        guard !channelId.isEmpty else {
            error = "Channel ID not configured"
            return
        }
        
        // Stop any existing timer
        stopMonitoring()
        
        isLoading = true
        
        // Check immediately
        Task {
            await checkLiveStatus()
            isLoading = false
        }
        
        // Then start periodic checks with initial interval of 1 minute
        timer = Timer.scheduledTimer(withTimeInterval: notLiveCheckInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkLiveStatus()
            }
        }
        
        // Start time updates
        startTimeUpdates()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        stopTimeUpdates()
        Logger.info("Monitoring stopped", category: .main)
    }
    
    private func startTimeUpdates() {
        // Format initial time
        updateCurrentTime()
        
        // Set up timer to update every second
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a" // 12-hour format with AM/PM
        currentTime = formatter.string(from: Date())
    }
    
    private func stopTimeUpdates() {
        timeTimer?.invalidate()
        timeTimer = nil
    }
    
    private func checkLiveStatus() async {
        guard let youtubeService = youtubeService else { return }
        
        // Create a local copy of the service to avoid isolation issues
        let service = youtubeService
        
        do {
            // Get the latest values from preferences
            let currentChannelId = channelId
            let currentCachedChannelId = cachedChannelId
            let currentUploadPlaylistId = uploadPlaylistId
            
            // If we don't have a cached channel ID or playlist ID, resolve it
            if currentCachedChannelId.isEmpty || currentUploadPlaylistId.isEmpty {
                // Clear any cached video data when resolving a new channel
                service.clearCache()
                
                // Resolve the channel identifier
                let (resolvedChannelId, resolvedPlaylistId) = try await service.resolveChannelIdentifier(currentChannelId)
                
                // Update resolved info in PreferencesManager
                PreferencesManager.shared.setResolvedChannelInfo(
                    channelId: resolvedChannelId,
                    playlistId: resolvedPlaylistId
                )
                
                // Use the newly resolved values for this check
                let status = try await service.checkLiveStatus(
                    channelId: resolvedChannelId,
                    uploadPlaylistId: resolvedPlaylistId
                )
                
                // Update UI state
                isLive = status.isLive
                viewerCount = status.viewerCount
                title = status.title
                error = nil
            } else {
                // Use existing cached values
                let status = try await service.checkLiveStatus(
                    channelId: currentCachedChannelId,
                    uploadPlaylistId: currentUploadPlaylistId
                )
                
                // Update UI state
                isLive = status.isLive
                viewerCount = status.viewerCount
                title = status.title
                error = nil
            }
            
            Logger.debug("Status updated - isLive: \(isLive), viewers: \(viewerCount), title: \(title)", category: .main)
            
        } catch let serviceError {
            if case YouTubeError.quotaExceeded = serviceError {
                self.error = "YouTube API quota exceeded. Please try again later."
            } else {
                self.error = "Failed to check live status: \(serviceError.localizedDescription)"
            }
            Logger.error("Failed to check live status: \(serviceError.localizedDescription)", category: .main)
        }
    }
    
    func updateApiKey(_ newApiKey: String) {
        if PreferencesManager.shared.updateApiKey(newApiKey) {
            // The notification handler will reinitialize the service
            error = nil
        } else {
            error = "Failed to save API key to Keychain"
        }
    }
    
    func updateChannelId(_ newChannelId: String) {
        // Use PreferencesManager to update channel ID
        // This will trigger notifications that we observe
        PreferencesManager.shared.updateChannelId(newChannelId)
    }
} 