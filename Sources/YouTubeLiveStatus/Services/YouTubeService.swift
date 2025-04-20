import Foundation
import GoogleAPIClientForREST_YouTube
import GTMSessionFetcherCore
import os

struct LiveStatus {
    let isLive: Bool
    let viewerCount: Int
    let title: String
    let videoId: String
}

enum YouTubeError: Error {
    case invalidChannelId
    case invalidApiKey
    case quotaExceeded
    case networkError
    case unknownError
}

@MainActor
class YouTubeService {
    private let service: GTLRYouTubeService
    private var currentLiveVideoId: String?
    
    init(apiKey: String) throws {
        guard !apiKey.isEmpty else {
            throw YouTubeError.invalidApiKey
        }
        
        Logger.info("YouTubeService initialized with API key", category: .youtube)
        service = GTLRYouTubeService()
        service.apiKey = apiKey
    }
    
    private func executeQuery<T: GTLRObject>(_ query: GTLRQuery) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            service.executeQuery(query) { (ticket: GTLRServiceTicket, response: Any?, error: Error?) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let response = response as? T else {
                    continuation.resume(throwing: YouTubeError.unknownError)
                    return
                }
                
                continuation.resume(returning: response)
            }
        }
    }
    
    func resolveChannelIdentifier(_ identifier: String) async throws -> (String, String) {
        // If it's already a channel ID, return it
        if identifier.hasPrefix("UC") {
            let query = GTLRYouTubeQuery_ChannelsList.query(withPart: ["contentDetails"])
            query.identifier = [identifier]
            
            let response: GTLRYouTube_ChannelListResponse = try await executeQuery(query)
            
            guard let channel = response.items?.first,
                  let uploadsPlaylistId = channel.contentDetails?.relatedPlaylists?.uploads else {
                throw YouTubeError.invalidChannelId
            }
            
            return (identifier, uploadsPlaylistId)
        }
        
        // Otherwise, search for the channel
        let query = GTLRYouTubeQuery_SearchList.query(withPart: ["id"])
        query.q = identifier
        query.type = ["channel"]
        query.maxResults = 1
        
        let response: GTLRYouTube_SearchListResponse = try await executeQuery(query)
        
        guard let channelId = response.items?.first?.identifier?.channelId else {
            throw YouTubeError.invalidChannelId
        }
        
        // Now get the uploads playlist ID
        let channelQuery = GTLRYouTubeQuery_ChannelsList.query(withPart: ["contentDetails"])
        channelQuery.identifier = [channelId]
        
        let channelResponse: GTLRYouTube_ChannelListResponse = try await executeQuery(channelQuery)
        
        guard let channel = channelResponse.items?.first,
              let uploadsPlaylistId = channel.contentDetails?.relatedPlaylists?.uploads else {
            throw YouTubeError.invalidChannelId
        }
        
        return (channelId, uploadsPlaylistId)
    }
    
    func checkLiveStatus(channelId: String, uploadPlaylistId: String) async throws -> LiveStatus {
        // If we have a current live video ID, check that video first
        if let videoId = currentLiveVideoId {
            let videoQuery = GTLRYouTubeQuery_VideosList.query(withPart: ["snippet", "liveStreamingDetails"])
            videoQuery.identifier = [videoId]
            
            let videoResponse: GTLRYouTube_VideoListResponse = try await executeQuery(videoQuery)
            
            guard let video = videoResponse.items?.first else {
                currentLiveVideoId = nil
                throw YouTubeError.unknownError
            }
            
            let isLive = video.snippet?.liveBroadcastContent == "live"
            let viewerCount = video.liveStreamingDetails?.concurrentViewers?.intValue ?? 0
            let title = video.snippet?.title ?? ""
            
            // If video is no longer live, clear the ID and we'll check the playlist next time
            if !isLive {
                currentLiveVideoId = nil
            }
            
            return LiveStatus(isLive: isLive, viewerCount: viewerCount, title: title, videoId: videoId)
        }
        
        // If no current live video or it's no longer live, check the most recent video
        let playlistQuery = GTLRYouTubeQuery_PlaylistItemsList.query(withPart: ["snippet"])
        playlistQuery.playlistId = uploadPlaylistId
        playlistQuery.maxResults = 1
        
        let playlistResponse: GTLRYouTube_PlaylistItemListResponse = try await executeQuery(playlistQuery)
        
        guard let videoId = playlistResponse.items?.first?.snippet?.resourceId?.videoId else {
            throw YouTubeError.unknownError
        }
        
        // Check if the video is live
        let videoQuery = GTLRYouTubeQuery_VideosList.query(withPart: ["snippet", "liveStreamingDetails"])
        videoQuery.identifier = [videoId]
        
        let videoResponse: GTLRYouTube_VideoListResponse = try await executeQuery(videoQuery)
        
        guard let video = videoResponse.items?.first else {
            throw YouTubeError.unknownError
        }
        
        let isLive = video.snippet?.liveBroadcastContent == "live"
        let viewerCount = video.liveStreamingDetails?.concurrentViewers?.intValue ?? 0
        let title = video.snippet?.title ?? ""
        
        // If the video is live, store its ID for future checks
        if isLive {
            currentLiveVideoId = videoId
        }
        
        return LiveStatus(isLive: isLive, viewerCount: viewerCount, title: title, videoId: videoId)
    }
    
    private func mapError(_ error: Error) -> YouTubeError {
        let nsError = error as NSError
        
        if nsError.domain == kGTLRErrorObjectDomain {
            if let errorJSON = nsError.userInfo["error"] as? [String: Any],
               let errors = errorJSON["errors"] as? [[String: Any]],
               let firstError = errors.first,
               let reason = firstError["reason"] as? String {
                
                switch reason {
                case "quotaExceeded":
                    return .quotaExceeded
                case "invalidChannelId":
                    return .invalidChannelId
                case "invalidApiKey":
                    return .invalidApiKey
                default:
                    return .unknownError
                }
            }
        }
        
        return .networkError
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