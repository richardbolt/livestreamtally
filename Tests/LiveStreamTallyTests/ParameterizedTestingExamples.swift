//
//  ParameterizedTestingExamples.swift
//  LiveStreamTallyTests
//
//  Created as an example of Swift Testing framework's parameterized tests
//

import Testing
@testable import LiveStreamTally

// Example of a parameterized test suite
@Suite("Parameterized Testing Examples")
struct ParameterizedTests {
    
    // Example 1: Testing multiple channel ID formats
    @Test("Should validate different channel ID formats",
          arguments: [
            "UC1234567890",          // Standard channel ID
            "@Username",             // Handle with @ prefix
            "Username",              // Handle without @ prefix
            "channel/UC1234567890",  // Full channel path 
          ])
    func channelIdValidation(channelId: String) {
        let isValid = !channelId.isEmpty
        #expect(isValid, "Channel ID should not be empty")
    }
    
    // Example 2: Testing with multiple parameter types
    @Test("Should format viewer counts correctly",
          arguments: [
            (0, "0 viewers"),
            (1, "1 viewer"),
            (5, "5 viewers"),
            (1000, "1K viewers"),
            (1500, "1.5K viewers"),
            (10000, "10K viewers"),
            (2000000, "2M viewers")
          ])
    func viewerCountFormatting(count: Int, expected: String) {
        let formatted = formatViewerCount(count)
        #expect(formatted == expected, "Expected \(expected) for count \(count), but got \(formatted)")
    }
    
    // Helper method for formatting viewer counts
    private func formatViewerCount(_ count: Int) -> String {
        switch count {
        case 0:
            return "0 viewers"
        case 1:
            return "1 viewer"
        case 2..<1000:
            return "\(count) viewers"
        case 1000..<10000:
            let thousands = Double(count) / 1000.0
            return "\(thousands.formatted(.number.precision(.fractionLength(0...1))))K viewers"
        case 10000..<1000000:
            let thousands = Double(count) / 1000.0
            return "\(Int(thousands))K viewers"
        default:
            let millions = Double(count) / 1000000.0
            return "\(millions.formatted(.number.precision(.fractionLength(0...1))))M viewers"
        }
    }
    
    // Example 3: Testing error handling with different input types
    @Test("Should handle different error cases",
          arguments: [
            YouTubeError.invalidChannelId,
            YouTubeError.invalidApiKey,
            YouTubeError.quotaExceeded,
            YouTubeError.unknownError
          ])
    func errorMessageGeneration(error: YouTubeError) {
        let errorMessage = generateErrorMessage(from: error)
        #expect(!errorMessage.isEmpty, "Error message should not be empty")
        
        // You could also check for specific content in each error message
        switch error {
        case .invalidChannelId:
            #expect(errorMessage.contains("channel"), "Error message should mention channel")
        case .invalidApiKey:
            #expect(errorMessage.contains("API key"), "Error message should mention API key")
        case .quotaExceeded:
            #expect(errorMessage.contains("quota"), "Error message should mention quota")
        case .networkError:
            #expect(errorMessage.contains("network"), "Error message should mention network")
        case .unknownError:
            #expect(errorMessage.contains("unknown"), "Error message should mention unknown")
        }
    }
    
    // Helper method for generating error messages
    private func generateErrorMessage(from error: YouTubeError) -> String {
        switch error {
        case .invalidChannelId:
            return "Invalid YouTube channel ID or handle. Please check your input."
        case .invalidApiKey:
            return "Invalid YouTube API key. Please check your API key in settings."
        case .quotaExceeded:
            return "YouTube API quota exceeded. Please try again later."
        case .networkError:
            return "Network error occurred. Please check your internet connection."
        case .unknownError:
            return "An unknown error occurred with the YouTube API."
        }
    }
} 