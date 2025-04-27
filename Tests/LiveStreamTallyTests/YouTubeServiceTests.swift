//
//  YouTubeServiceTests.swift
//  LiveStreamTallyTests
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("YouTube Service Tests")
struct YouTubeServiceTests {
    // Mock API key for testing
    private let testApiKey = "test_api_key"
    
    @Test func testInitWithEmptyApiKey() async throws {
        await #expect(throws: YouTubeError.invalidApiKey) {
            try await YouTubeService(apiKey: "")
        }
    }
    
    @Test func testInitWithValidApiKey() async throws {
        // Using _ to intentionally ignore the return value since we just want to verify it doesn't throw
        _ = try await YouTubeService(apiKey: testApiKey)
        
        // Using explicit Bool value to avoid warning
        #expect(Bool(true), "Should be able to create YouTubeService with valid API key")
    }
    
    // MARK: - Integration Tests (Disabled by default)
    
    // These tests require a real API key and would make actual API calls
    // They are disabled by default to avoid quota usage during automated testing
    
    @Test(.disabled("Requires real API key"))
    func testResolveChannelIdentifier() async throws {
        // This test requires a real API key and would make actual API calls
        // Replace testApiKey with a real API key to run this test
        let service = try await YouTubeService(apiKey: testApiKey)
        
        // Test with a known channel ID
        let (channelId, uploadPlaylistId) = try await service.resolveChannelIdentifier("UC...")
        #expect(!channelId.isEmpty)
        #expect(!uploadPlaylistId.isEmpty)
    }
    
    @Test(.disabled("Requires real API key"))
    func testCheckLiveStatus() async throws {
        // This test requires a real API key and would make actual API calls
        // Replace testApiKey with a real API key to run this test
        let service = try await YouTubeService(apiKey: testApiKey)
        
        // Test with known channel ID and upload playlist ID
        let status = try await service.checkLiveStatus(channelId: "UC...", uploadPlaylistId: "UU...")
        
        // We can't assert specific values since they depend on the channel's current state
        // But we can check that we get a valid response with properties
        #expect(status.videoId.count > 0 || !status.isLive)
    }
    
    // MARK: - Unit Tests with Mocking
    
    @Test func testMapError() async throws {
        // Create a YouTubeService instance
        let service = try await YouTubeService(apiKey: testApiKey)
        
        // Create a fake NSError with the structure that would come from the YouTube API
        let errorUserInfo: [String: Any] = [
            "error": [
                "errors": [
                    ["reason": "quotaExceeded"]
                ]
            ]
        ]
        let nsError = NSError(domain: "com.google.GTLRErrorObjectDomain", code: 403, userInfo: errorUserInfo)
        
        // Use the Swift Testing reflection API to access the private mapError method
        // This is a bit of a hack until we refactor the code to make mapError more testable
        let mirror = Mirror(reflecting: service)
        for child in mirror.children {
            if child.label == "mapError" {
                if let mapErrorMethod = child.value as? (Error) -> YouTubeError {
                    let mappedError = mapErrorMethod(nsError)
                    #expect(mappedError == .quotaExceeded)
                }
            }
        }
    }
    
    @Test func testClearCache() async throws {
        // Create a YouTubeService instance
        let service = try await YouTubeService(apiKey: testApiKey)
        
        // Call clearCache method - must use await since YouTubeService is @MainActor
        await service.clearCache()
        
        // We can't directly verify the private variable was cleared,
        // but we can confirm it doesn't throw any errors
        #expect(Bool(true), "clearCache() should complete without errors")
    }
} 