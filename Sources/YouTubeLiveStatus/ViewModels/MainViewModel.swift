import Foundation
import SwiftUI
import os

@MainActor
class MainViewModel: ObservableObject {
    @Published var isLive = false
    @Published var viewerCount = 0
    @Published var streamTitle = ""
    @Published var error: String?
    
    private var youtubeService: YouTubeService?
    private var channelId: String?
    private var timer: Timer?
    
    init(apiKey: String? = nil, channelId: String? = nil) {
        // Try to use cached channel ID first, fall back to provided one
        let cachedId = UserDefaults.standard.string(forKey: "youtube_channel_id_cached")
        initialize(apiKey: apiKey, channelId: cachedId ?? channelId)
    }
    
    func initialize(apiKey: String?, channelId: String?) {
        self.channelId = channelId
        
        do {
            youtubeService = try YouTubeService(apiKey: apiKey)
            Logger.info("MainViewModel initialized", category: .main)
            error = nil
        } catch {
            Logger.error("Failed to initialize YouTubeService: \(error.localizedDescription)", category: .main)
            self.error = "Failed to initialize: \(error.localizedDescription)"
        }
    }
    
    func startMonitoring() {
        guard let channelId = channelId else {
            Logger.error("Channel ID not configured", category: .main)
            error = "Channel ID not configured"
            return
        }
        
        Logger.info("Starting monitoring for channel: \(channelId)", category: .main)
        
        // Cancel any existing timer
        timer?.invalidate()
        
        // Create a new timer that fires every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkLiveStatus()
            }
        }
        
        // Fire immediately
        Task {
            await checkLiveStatus()
        }
        
        Logger.debug("Monitoring timer started", category: .main)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        Logger.info("Monitoring stopped", category: .main)
    }
    
    private func checkLiveStatus() async {
        guard let service = youtubeService, let channelId = channelId else {
            return
        }
        
        do {
            let (live, count, title) = try await service.checkLiveStatus(channelIdentifier: channelId)
            
            // Update UI on main thread
            await MainActor.run {
                self.isLive = live
                self.viewerCount = count
                self.streamTitle = title
                self.error = nil
            }
            
            Logger.debug("Status updated - isLive: \(live), viewers: \(count), title: \(title)", category: .main)
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            Logger.error("Failed to check live status: \(error.localizedDescription)", category: .main)
        }
    }
} 