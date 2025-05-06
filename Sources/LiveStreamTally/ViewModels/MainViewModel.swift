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
    // Static cached YouTubeService to prevent recreating it
    private static var cachedYouTubeService: YouTubeService?
    
    @Published var isLive = false {
        didSet {
            if oldValue != isLive {
                // Update timer interval when live status changes
                updateTimerInterval()
                Logger.debug("isLive changed from \(oldValue) to \(isLive)", category: .main)
            }
        }
    }
    @Published var viewerCount = 0 {
        didSet {
            if oldValue != viewerCount {
                Logger.debug("viewerCount changed from \(oldValue) to \(viewerCount)", category: .main)
            }
        }
    }
    @Published var title = "" {
        didSet {
            if oldValue != title {
                Logger.debug("title changed to: \(title)", category: .main)
            }
        }
    }
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
    private var timePublisher: AnyCancellable?
    
    // Shared date formatter for time updates
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a" // 12-hour format with AM/PM
        return formatter
    }()
    
    // Add cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(apiKey: String? = nil) {
        Logger.debug("MainViewModel.init() called", category: .main)
        // Initialize with current values from PreferencesManager
        self.channelId = PreferencesManager.shared.getChannelId()
        self.cachedChannelId = PreferencesManager.shared.cachedChannelId
        self.uploadPlaylistId = PreferencesManager.shared.uploadPlaylistId
        
        // Initialize with provided API key or from PreferencesManager
        let keyToUse = apiKey ?? PreferencesManager.shared.getApiKey()
        
        if let keyToUse = keyToUse, !keyToUse.isEmpty {
            do {
                // Use cached service if it exists, otherwise create a new one
                if MainViewModel.cachedYouTubeService == nil {
                    MainViewModel.cachedYouTubeService = try YouTubeService(apiKey: keyToUse)
                }
                
                // Use the cached service
                youtubeService = MainViewModel.cachedYouTubeService
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
        Logger.debug("REGISTERING NOTIFICATIONS in MainViewModel", category: .main)
        
        // Register for API key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApiKeyChanged),
            name: PreferencesManager.NotificationNames.apiKeyChanged,
            object: nil
        )
        
        // Register for channel ID changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChannelChanged),
            name: PreferencesManager.NotificationNames.channelChanged,
            object: nil
        )
        
        // Register for interval changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIntervalChanged),
            name: PreferencesManager.NotificationNames.intervalChanged,
            object: nil
        )
    }
    
    @objc private func handleApiKeyChanged() {
        // Reinitialize YouTubeService with new API key
        if let apiKey = PreferencesManager.shared.getApiKey() {
            do {
                // Create a new service and update the cache
                MainViewModel.cachedYouTubeService = try YouTubeService(apiKey: apiKey)
                youtubeService = MainViewModel.cachedYouTubeService
                error = nil
            } catch let serviceError {
                error = "Failed to initialize YouTube service: \(serviceError.localizedDescription)"
            }
        }
    }
    
    @objc private func handleChannelChanged() {
        // Create a Task to handle the async work
        Task { @MainActor [weak self] in
            await self?.handleChannelChangedAsync()
        }
    }
    
    @objc private func handleChannelChangedAsync() async {
        // Clear YouTube service cache when channel changes
        youtubeService?.clearCache()
        
        // Restart monitoring if active
        if timer != nil {
            await stopMonitoring()
            await startMonitoring()
        }
    }
    
    @objc private func handleIntervalChanged() {
        // Update timer interval when intervals are changed in preferences
        updateTimerInterval()
    }
    
    func getAPIKey() -> String? {
        return PreferencesManager.shared.getApiKey()
    }
    
    private func updateTimerInterval() {
        guard timer != nil else { return }
        
        // Stop existing timer
        timer?.invalidate()
        
        // Get current intervals from preferences
        let liveInterval = PreferencesManager.shared.getLiveCheckInterval()
        let notLiveInterval = PreferencesManager.shared.getNotLiveCheckInterval()
        
        // Create new timer with appropriate interval
        timer = Timer.scheduledTimer(withTimeInterval: isLive ? liveInterval : notLiveInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkLiveStatus()
            }
        }
    }
    
    func startMonitoring() async {
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
        await stopMonitoring()
        
        isLoading = true
        
        // Check immediately
        Task {
            await checkLiveStatus()
            isLoading = false
        }
        
        // Get initial interval from preferences
        let initialInterval = PreferencesManager.shared.getNotLiveCheckInterval()
        
        // Then start periodic checks with initial interval
        timer = Timer.scheduledTimer(withTimeInterval: initialInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkLiveStatus()
            }
        }
        
        // Start time updates
        startTimeUpdates()
    }
    
    func stopMonitoring() async {
        timer?.invalidate()
        timer = nil
        stopTimeUpdates()
        Logger.info("Monitoring stopped", category: .main)
    }
    
    private func startTimeUpdates() {
        Logger.debug("TimeUpdates publisher started", category: .main)
        // Format initial time
        currentTime = timeFormatter.string(from: Date())
        
        // Use a publisher that doesn't trigger as many UI updates
        timePublisher = Timer.publish(every: 1.0, on: .main, in: .default)
            .autoconnect()
            // Throttle updates to reduce frequency
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Only update if the formatted time is actually different
                let newTime = self.timeFormatter.string(from: Date())
                if self.currentTime != newTime {
                    self.currentTime = newTime
                }
            }
    }
    
    private func stopTimeUpdates() {
        Logger.debug("TimeUpdates publisher stopped", category: .main)
        timePublisher?.cancel()
        timePublisher = nil
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