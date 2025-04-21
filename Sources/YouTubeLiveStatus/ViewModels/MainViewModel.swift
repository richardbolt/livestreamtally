import Foundation
import SwiftUI
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
    
    @AppStorage("youtube_channel_id") private var channelId = ""
    @AppStorage("youtube_channel_id_cached") private var cachedChannelId = ""
    @AppStorage("youtube_upload_playlist_id") private var uploadPlaylistId = ""
    
    private var youtubeService: YouTubeService?
    private var timer: Timer?
    
    // Timer intervals
    private let liveCheckInterval: TimeInterval = 30.0
    private let notLiveCheckInterval: TimeInterval = 60.0
    
    init(apiKey: String? = nil) {
        if let apiKey = apiKey, !apiKey.isEmpty {
            do {
                youtubeService = try YouTubeService(apiKey: apiKey)
                self.error = nil
            } catch let serviceError {
                self.error = "Failed to initialize YouTube service: \(serviceError.localizedDescription)"
            }
        }
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
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        Logger.info("Monitoring stopped", category: .main)
    }
    
    private func checkLiveStatus() async {
        guard let youtubeService = youtubeService else { return }
        
        do {
            // If we don't have a cached channel ID or playlist ID, resolve it
            if cachedChannelId.isEmpty || uploadPlaylistId.isEmpty {
                let (resolvedChannelId, resolvedPlaylistId) = try await youtubeService.resolveChannelIdentifier(channelId)
                cachedChannelId = resolvedChannelId
                uploadPlaylistId = resolvedPlaylistId
            }
            
            let status = try await youtubeService.checkLiveStatus(channelId: cachedChannelId, uploadPlaylistId: uploadPlaylistId)
            
            isLive = !isLive // status.isLive
            viewerCount = status.viewerCount
            title = status.title
            Logger.debug("Status updated - isLive: \(isLive), viewers: \(viewerCount), title: \(title), videoId: \(status.videoId)", category: .main)
            error = nil
            
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
        do {
            youtubeService = try YouTubeService(apiKey: newApiKey)
            error = nil
        } catch let serviceError {
            error = "Failed to initialize YouTube service: \(serviceError.localizedDescription)"
        }
    }
    
    func updateChannelId(_ newChannelId: String) {
        // Only update the user-entered channel ID, don't touch the cached one
        channelId = newChannelId
        // Clear the cached values when the channel ID changes
        cachedChannelId = ""
        uploadPlaylistId = ""
    }
} 