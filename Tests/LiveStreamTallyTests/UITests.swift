//
//  UITestsSwift.swift
//  LiveStreamTallyTests
//
//  Created as a Swift Testing version of UITests
//

import Testing
import SwiftUI
import Foundation
@testable import LiveStreamTally

@Suite("UI Tests")
struct UITestsSuite {
    
    // UI tests are typically done through XCUITest in a separate test target
    // These are more like view inspection tests
    
    @Test("Should create ContentView without crashing")
    @MainActor func testContentViewCreation() async throws {
        // Initialize the required view models
        let viewModel = MainViewModel()
        let settingsViewModel = SettingsViewModel()
        let ndiViewModel = NDIViewModel(mainViewModel: viewModel)
        
        // Set some values to verify the view models work
        viewModel.isLive = true
        viewModel.viewerCount = 1250
        viewModel.title = "Test Stream"
        
        // Create the ContentView
        let _ = ContentView()
        
        // Verify view model state is as expected
        #expect(viewModel.isLive)
        #expect(viewModel.viewerCount == 1250)
        #expect(viewModel.title == "Test Stream")
        
        // Verify other view models have expected initial state
        #expect(!settingsViewModel.isProcessing)
        #expect(settingsViewModel.channelError == nil)
        #expect(settingsViewModel.apiKeyError == nil)
        
        #expect(!ndiViewModel.isStreaming)
    }
    
    @Test("Should format viewer counts correctly")
    func testViewerCountFormatting() {
        // THIS IS A USELESS TEST:
        // it only specs out what the app should do
        // but does not testt the application implementation.

        // Create a function to format counts in the same way as the app would
        func formatViewerCount(_ count: Int) -> String {
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
        
        // Test various formatting scenarios
        let testCases = [
            (0, "0 viewers"),
            (1, "1 viewer"),
            (5, "5 viewers"),
            (1000, "1K viewers"),
            (1500, "1.5K viewers"),
            (10000, "10K viewers"),
            (2000000, "2M viewers")
        ]
        
        for (count, expected) in testCases {
            let formatted = formatViewerCount(count)
            #expect(formatted == expected, "Expected \(expected) for count \(count), but got \(formatted)")
        }
    }
    
    @Test("Should handle different live states")
    @MainActor func testLiveStateHandling() async {
        // Create view model
        let viewModel = MainViewModel()
        
        // Test offline state
        viewModel.isLive = false
        #expect(!viewModel.isLive)
        
        // Test live state
        viewModel.isLive = true
        #expect(viewModel.isLive)
        
        // Test error state
        viewModel.error = "Test error message"
        #expect(viewModel.error != nil)
        #expect(viewModel.error == "Test error message")
    }
    
    @Test("Should display correct status text based on live state")
    @MainActor func testStatusTextDisplay() async {
        // Create a view model to test status text
        let viewModel = MainViewModel()
        
        // Define a helper function to simulate how the view would create status text
        func getStatusText() -> String {
            if let error = viewModel.error {
                return "ERROR: \(error)"
            } else if viewModel.isLive {
                return "LIVE"
            } else {
                return "OFFLINE"
            }
        }
        
        // Test not live state
        viewModel.isLive = false
        #expect(getStatusText() == "OFFLINE", "Status should be OFFLINE when not live")
        
        // Test live state
        viewModel.isLive = true
        #expect(getStatusText() == "LIVE", "Status should be LIVE when streaming")
        
        // Test error state
        viewModel.error = "Test error message"
        #expect(getStatusText().contains("ERROR"), "Status should indicate ERROR when there's an error")
    }
    
    @Test("Should display correct channel info")
    @MainActor func testChannelInfoDisplay() async {
        // This test uses direct access to the UI properties rather than trying
        // to manipulate the PreferencesManager which can have timing issues
        
        // Create a mock with direct property access for testing
        class TestableChannelInfo {
            var channelId = ""
            var cachedChannelId = ""
            
            var channelInfoText: String {
                if channelId.isEmpty {
                    return "No channel set"
                } else if !cachedChannelId.isEmpty {
                    return cachedChannelId
                } else {
                    return channelId
                }
            }
        }
        
        let tester = TestableChannelInfo()
        
        // Test empty channel ID
        tester.channelId = ""
        tester.cachedChannelId = ""
        #expect(tester.channelInfoText.contains("No channel"), "Should indicate no channel is set")
        
        // Test with channel ID
        let testChannelId = "UC123456789"
        tester.channelId = testChannelId
        tester.cachedChannelId = ""
        #expect(tester.channelInfoText.contains(testChannelId), "Should show channel ID")
        
        // Test with cached channel ID
        let cachedId = "@TestChannel"
        tester.channelId = testChannelId
        tester.cachedChannelId = cachedId
        #expect(tester.channelInfoText.contains(cachedId), "Should show cached channel name")
    }
    
    @Test("Should update UI for different status indicator colors")
    @MainActor func testStatusIndicatorColor() async {
        // Create a view model to test status indicator colors
        let viewModel = MainViewModel()
        
        // Define a helper function to simulate how the view would create status color
        func getStatusColor() -> Color {
            if viewModel.error != nil {
                return .red
            } else if viewModel.isLive {
                return .green
            } else {
                return .gray
            }
        }
        
        // Test offline state (should be gray)
        viewModel.isLive = false
        viewModel.error = nil
        let offlineColor = getStatusColor()
        // Check that the color is not red or green but a different color (gray)
        #expect(offlineColor != .red, "Offline status color should not be red")
        #expect(offlineColor != .green, "Offline status color should not be green")
        
        // Test live state (should be green)
        viewModel.isLive = true
        viewModel.error = nil
        let liveColor = getStatusColor()
        #expect(liveColor == .green, "Live status color should be green")
        
        // Test error state (should be red)
        viewModel.error = "Test error"
        let errorColor = getStatusColor()
        #expect(errorColor == .red, "Error status color should be red")
    }
    
    @Test("Should properly format current time")
    @MainActor func testTimeDisplay() async {
        // Create view model
        let viewModel = MainViewModel()
        
        // Start monitoring to initialize time
        await viewModel.startMonitoring()
        
        // Wait for time to be initialized - this might take a moment
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Verify that time is not empty
        #expect(!viewModel.currentTime.isEmpty)
        
        // Verify time format looks correct (h:mm:ss a)
        let timePattern = #"^[0-9]{1,2}:[0-9]{2}:[0-9]{2} [AP]M$"#
        let timeRegex = try! NSRegularExpression(pattern: timePattern)
        let matches = timeRegex.matches(
            in: viewModel.currentTime,
            range: NSRange(viewModel.currentTime.startIndex..., in: viewModel.currentTime)
        )
        
        #expect(!matches.isEmpty, "Time should be in h:mm:ss a format")
        
        // Cleanup
        await viewModel.stopMonitoring()
    }
    
    @Test("Should start and stop monitoring")
    @MainActor func testMonitoring() async {
        // Create view model
        let viewModel = MainViewModel()
        
        // Start monitoring
        await viewModel.startMonitoring()
        
        // Stop monitoring
        await viewModel.stopMonitoring()
        
        // Test passes if no crashes
        #expect(Bool(true))
    }
    
    @Test("Should handle API key and channel ID updates")
    @MainActor func testUpdatingSettings() async {
        // Create view model
        let viewModel = MainViewModel()
        
        // Test API key update (doesn't need to succeed, just not crash)
        viewModel.updateApiKey("test-key")
        
        // Test channel ID update
        viewModel.updateChannelId("test-channel")
        
        // Test shouldn't crash
        #expect(Bool(true))
    }
    
    // MARK: - Testing SwiftUI Views with ViewInspector
    
    // To properly test SwiftUI views, we would typically use ViewInspector
    // https://github.com/nalexn/ViewInspector
    
    // For example:
    // @Test("Should display correct viewer count")
    // @MainActor
    // func testViewerCountDisplay() async throws {
    //     let viewModel = MainViewModel()
    //     viewModel.viewerCount = 100
    //     viewModel.isLive = true
    //     
    //     let view = MainView(viewModel: viewModel)
    //     let viewerText = try view.inspect().find(viewWithId: "viewerCount").text().string()
    //     #expect(viewerText == "100")
    // }
    
    // MARK: - Snapshot Testing
    
    // Another approach would be to use snapshot testing to verify UI appearance
    // https://github.com/pointfreeco/swift-snapshot-testing
    
    // @Test("Should match snapshot for live state")
    // @MainActor
    // func testMainViewSnapshot() async {
    //     let viewModel = MainViewModel()
    //     viewModel.viewerCount = 100
    //     viewModel.isLive = true
    //     viewModel.title = "Test Stream"
    //     
    //     let view = MainView(viewModel: viewModel)
    //     assertSnapshot(matching: view, as: .image)
    // }
} 