//
//  YouTubeServiceTests.swift
//  LiveStreamTallyTests
//
//  Created as a test scaffolding
//

import XCTest
@testable import LiveStreamTally

// Note: Testing with Swift 6.1's actor isolation is challenging in XCTest.
// Individual test methods are marked as async rather than marking the entire class with @MainActor
// to avoid issues with XCTestCase's non-Sendable nature.
final class YouTubeServiceTests: XCTestCase {
    
    // Mock API key for testing
    private let testApiKey = "test_api_key"
    
    func testInitWithEmptyApiKey() async throws {
        do {
            _ = try await YouTubeService(apiKey: "")
            XCTFail("YouTubeService should not initialize with empty API key")
        } catch let error as YouTubeError {
            XCTAssertEqual(error, YouTubeError.invalidApiKey)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testInitWithValidApiKey() async throws {
        do {
            let service = try await YouTubeService(apiKey: testApiKey)
            XCTAssertNotNil(service)
        } catch {
            XCTFail("YouTubeService should initialize with valid API key: \(error)")
        }
    }
    
    // MARK: - Integration Tests (Disabled by default)
    
    // These tests require a real API key and would make actual API calls
    // They are disabled by default to avoid quota usage during automated testing
    
    func disabledTestResolveChannelIdentifier() async throws {
        // This test requires a real API key and would make actual API calls
        // Replace testApiKey with a real API key to run this test
        let service = try await YouTubeService(apiKey: testApiKey)
        
        // Test with a known channel ID
        let (channelId, uploadPlaylistId) = try await service.resolveChannelIdentifier("UC...")
        XCTAssertFalse(channelId.isEmpty)
        XCTAssertFalse(uploadPlaylistId.isEmpty)
    }
    
    func disabledTestCheckLiveStatus() async throws {
        // This test requires a real API key and would make actual API calls
        // Replace testApiKey with a real API key to run this test
        let service = try await YouTubeService(apiKey: testApiKey)
        
        // Test with known channel ID and upload playlist ID
        let status = try await service.checkLiveStatus(channelId: "UC...", uploadPlaylistId: "UU...")
        
        // We can't assert specific values since they depend on the channel's current state
        // But we can check that we get a valid response
        XCTAssertNotNil(status)
    }
} 