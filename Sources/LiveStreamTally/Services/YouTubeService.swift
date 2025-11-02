//
//  YouTubeService.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import GoogleAPIClientForREST_YouTube
import GTMSessionFetcherCore
import os

// Mark the GoogleAPI types as implicitly Sendable for migration purposes
@preconcurrency import GoogleAPIClientForREST_YouTube

struct LiveStatus: Sendable {
    let isLive: Bool
    let viewerCount: Int
    let title: String
    let videoId: String
}

enum YouTubeError: Error, Sendable {
    case invalidChannelId
    case invalidApiKey
    case quotaExceeded
    case networkError
    case unknownError
}

// Using @MainActor to ensure isolation for Swift 6.1 compatibility
@MainActor
class YouTubeService: YouTubeServiceProtocol {
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
        Logger.debug("Calling YouTube API: \(String(describing: type(of: query)))", category: .youtube)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            // Use a local variable to capture service and avoid self capture
            let localService = service
            localService.executeQuery(query) { (ticket: GTLRServiceTicket, response: Any?, error: Error?) in
                if let error = error {
                    let mappedError = self.mapError(error)
                    continuation.resume(throwing: mappedError)
                    return
                }

                guard let response = response as? T else {
                    continuation.resume(throwing: YouTubeError.unknownError)
                    return
                }

                // Make a properly isolated copy of the response by creating a task
                // This is necessary to avoid data races when passing data across actor boundaries
                Task { @MainActor in
                    // Since we're using @MainActor for both this closure and the class,
                    // this access is properly isolated
                    continuation.resume(returning: response)
                }
            }
        }
    }
    
    func resolveChannelIdentifier(_ identifier: String) async throws -> (String, String) {
        // If it's already a channel ID, return it
        if identifier.hasPrefix("UC") {
            Logger.debug("Looking up channel by ID: \(identifier)", category: .youtube)
            
            let query = GTLRYouTubeQuery_ChannelsList.query(withPart: ["contentDetails"])
            query.identifier = [identifier]
            
            let response: GTLRYouTube_ChannelListResponse = try await executeQuery(query)
            
            guard let channel = response.items?.first,
                  let uploadsPlaylistId = channel.contentDetails?.relatedPlaylists?.uploads else {
                throw YouTubeError.invalidChannelId
            }
            
            return (identifier, uploadsPlaylistId)
        }
        
        // For all other inputs, use the forHandle parameter (works with or without @ prefix)
        // Clean up the identifier if it has spaces
        let handleToUse = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use the direct channel lookup with forHandle parameter
        Logger.debug("Looking up channel by handle: \(handleToUse)", category: .youtube)
        
        let query = GTLRYouTubeQuery_ChannelsList.query(withPart: ["id", "contentDetails"])
        query.forHandle = handleToUse
        
        let response: GTLRYouTube_ChannelListResponse = try await executeQuery(query)
        
        guard let channel = response.items?.first,
              let channelId = channel.identifier,
              let contentDetails = channel.contentDetails,
              let uploadsPlaylistId = contentDetails.relatedPlaylists?.uploads else {
            throw YouTubeError.invalidChannelId
        }
        
        Logger.debug("Resolved handle \(handleToUse) to channel ID: \(channelId)", category: .youtube)
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
            
            let isLive = video.liveStreamingDetails?.actualStartTime != nil && video.liveStreamingDetails?.actualEndTime == nil
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
        
        let isLive = video.liveStreamingDetails?.actualStartTime != nil && video.liveStreamingDetails?.actualEndTime == nil
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
    
    // Add this new method to clear cache when channel changes
    func clearCache() {
        Logger.debug("Clearing YouTubeService cache (currentLiveVideoId)", category: .youtube)
        currentLiveVideoId = nil
    }
}

// MARK: - Response Models

struct SearchResponse: Codable, Sendable {
    let items: [SearchItem]
}

struct SearchItem: Codable, Sendable {
    let id: VideoID
}

struct VideoID: Codable, Sendable {
    let videoId: String
}

struct VideoResponse: Codable, Sendable {
    let items: [Video]
}

struct Video: Codable, Sendable {
    let snippet: VideoSnippet
    let liveStreamingDetails: LiveStreamingDetails?
}

struct VideoSnippet: Codable, Sendable {
    let title: String
}

struct LiveStreamingDetails: Codable, Sendable {
    let concurrentViewers: String?
}

struct ChannelResponse: Codable, Sendable {
    let items: [Channel]
}

struct Channel: Codable, Sendable {
    let id: String
} 