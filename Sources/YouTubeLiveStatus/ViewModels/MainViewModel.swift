import Foundation
import SwiftUI
import os

@MainActor
final class MainViewModel: ObservableObject {
    @Published var isLive = false
    @Published var viewerCount = 0
    @Published var title = ""
    @Published var error: String?
    
    @AppStorage("youtube_channel_id") private var channelId = ""
    @AppStorage("youtube_upload_playlist_id") private var uploadPlaylistId = ""
    
    private var youtubeService: YouTubeService?
    private var timer: Timer?
    
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
    
    func startMonitoring() {
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
        
        // Check immediately
        Task {
            await checkLiveStatus()
        }
        
        // Then start periodic checks
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkLiveStatus()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkLiveStatus() async {
        guard let youtubeService = youtubeService else { return }
        
        do {
            // If we don't have a playlist ID or it's for a different channel, resolve it
            if uploadPlaylistId.isEmpty {
                let (resolvedChannelId, resolvedPlaylistId) = try await youtubeService.resolveChannelIdentifier(channelId)
                channelId = resolvedChannelId // Update to canonical form if needed
                uploadPlaylistId = resolvedPlaylistId
            }
            
            let status = try await youtubeService.checkLiveStatus(channelId: channelId, uploadPlaylistId: uploadPlaylistId)
            
            isLive = status.isLive
            viewerCount = status.viewerCount
            title = status.title
            error = nil
            
        } catch let serviceError {
            if case YouTubeError.quotaExceeded = serviceError {
                self.error = "YouTube API quota exceeded. Please try again later."
            } else {
                self.error = "Failed to check live status: \(serviceError.localizedDescription)"
            }
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
        // Clear the cached playlist ID when channel ID changes
        if newChannelId != channelId {
            uploadPlaylistId = ""
        }
        channelId = newChannelId
    }
} 