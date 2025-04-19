import Foundation
import GoogleAPIClientForREST_YouTube
import os

struct LiveStatus {
    let isLive: Bool
    let viewerCount: Int
    let title: String
}

enum YouTubeError: Error {
    case apiKeyNotConfigured
    case channelNotFound
    case invalidResponse
    case networkError(Error)
}

@MainActor
class YouTubeService {
    private let service: GTLRYouTubeService
    
    init(apiKey: String?) throws {
        guard let apiKey = apiKey else {
            throw YouTubeError.apiKeyNotConfigured
        }
        
        Logger.info("YouTubeService initialized with API key", category: .youtube)
        service = GTLRYouTubeService()
        service.apiKey = apiKey
    }
    
    func resolveChannelIdentifier(_ identifier: String) async throws -> String {
        Logger.debug("Resolving channel identifier: \(identifier)", category: .youtube)
        
        // If it's already a channel ID (starts with UC), return it
        if identifier.hasPrefix("UC") {
            return identifier
        }
        
        // Handle @ handles by removing the @ and using forHandle
        let handle = identifier.hasPrefix("@") ? String(identifier.dropFirst()) : identifier
        Logger.debug("Resolving handle: \(handle)", category: .youtube)
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create a channels list query
            let query = GTLRYouTubeQuery_ChannelsList.query(withPart: ["id"])
            query.forHandle = handle  // Use forHandle instead of forUsername
            
            // Execute the query
            service.executeQuery(query) { (ticket, result, error) in
                if let error = error {
                    Logger.error("Failed to resolve handle: \(error.localizedDescription)", category: .youtube)
                    continuation.resume(throwing: YouTubeError.networkError(error))
                    return
                }
                
                guard let channelList = result as? GTLRYouTube_ChannelListResponse,
                      let items = channelList.items,
                      !items.isEmpty,
                      let channelId = items[0].identifier else {
                    continuation.resume(throwing: YouTubeError.channelNotFound)
                    return
                }
                
                Logger.debug("Resolved handle to channel ID: \(channelId)", category: .youtube)
                continuation.resume(returning: channelId)
            }
        }
    }
    
    func checkLiveStatus(channelIdentifier: String) async throws -> (isLive: Bool, viewerCount: Int, title: String) {
        Logger.debug("Checking live status for channel: \(channelIdentifier)", category: .youtube)
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create a search query for live streams
            let searchQuery = GTLRYouTubeQuery_SearchList.query(withPart: ["snippet"])
            searchQuery.channelId = channelIdentifier
            searchQuery.eventType = "live"
            searchQuery.type = ["video"]
            
            // Execute the search query
            service.executeQuery(searchQuery) { [weak self] (ticket, result, error) in
                guard let self = self else { return }
                
                if let error = error {
                    Logger.error("Failed to check live status: \(error.localizedDescription)", category: .youtube)
                    continuation.resume(throwing: YouTubeError.networkError(error))
                    return
                }
                
                guard let searchList = result as? GTLRYouTube_SearchListResponse,
                      let items = searchList.items,
                      !items.isEmpty,
                      let videoId = items[0].identifier?.videoId else {
                    Logger.debug("No live streams found", category: .youtube)
                    continuation.resume(returning: (false, 0, ""))
                    return
                }
                
                // Get live streaming details
                let videoQuery = GTLRYouTubeQuery_VideosList.query(withPart: ["liveStreamingDetails", "snippet"])
                videoQuery.identifier = [videoId]
                
                // Execute the video query
                self.service.executeQuery(videoQuery) { (ticket, result, error) in
                    if let error = error {
                        Logger.error("Failed to get video details: \(error.localizedDescription)", category: .youtube)
                        continuation.resume(throwing: YouTubeError.networkError(error))
                        return
                    }
                    
                    guard let videoList = result as? GTLRYouTube_VideoListResponse,
                          let videos = videoList.items,
                          !videos.isEmpty else {
                        Logger.debug("No live streams found", category: .youtube)
                        continuation.resume(returning: (false, 0, ""))
                        return
                    }
                    
                    let video = videos[0]
                    guard let details = video.liveStreamingDetails,
                          let title = video.snippet?.title else {
                        Logger.debug("No live streams found", category: .youtube)
                        continuation.resume(returning: (false, 0, ""))
                        return
                    }
                    
                    let viewerCount = Int(truncating: details.concurrentViewers ?? 0)
                    Logger.debug("Found live stream - viewers: \(viewerCount), title: \(title)", category: .youtube)
                    continuation.resume(returning: (true, viewerCount, title))
                }
            }
        }
    }
}

// MARK: - Response Models

struct SearchResponse: Codable {
    let items: [SearchItem]
}

struct SearchItem: Codable {
    let id: VideoID
}

struct VideoID: Codable {
    let videoId: String
}

struct VideoResponse: Codable {
    let items: [Video]
}

struct Video: Codable {
    let snippet: VideoSnippet
    let liveStreamingDetails: LiveStreamingDetails?
}

struct VideoSnippet: Codable {
    let title: String
}

struct LiveStreamingDetails: Codable {
    let concurrentViewers: String?
}

struct ChannelResponse: Codable {
    let items: [Channel]
}

struct Channel: Codable {
    let id: String
} 