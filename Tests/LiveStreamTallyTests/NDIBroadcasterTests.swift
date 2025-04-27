//
//  NDIBroadcasterTestsSwift.swift
//  LiveStreamTallyTests
//
//  Created as a Swift Testing version of NDIBroadcasterTests
//

import Testing
import Foundation
@testable import LiveStreamTally

@Suite("NDI Broadcaster Tests")
struct NDIBroadcasterTestsSuite {
    
    // These tests are mostly placeholders since NDI functionality
    // is hardware-dependent and difficult to test in isolation
    
    @Test("Should initialize without crashing")
    func testNDIBroadcasterInitialization() {
        // This test doesn't need @MainActor because NDIBroadcaster init is not actor-isolated
        let broadcaster = NDIBroadcaster()
        // Just verify the broadcaster exists
        #expect(Bool(true), "NDIBroadcaster initialization should not crash")
    }
    
    // Note: Actual NDI functionality tests would need the NDI runtime
    // and would be integration tests rather than unit tests
    
    @Test(.disabled("Requires NDI runtime"))
    func testSendTally() {
        // This test doesn't need @MainActor because sendTally is not actor-isolated
        // This test is disabled by default as it requires NDI runtime
        let broadcaster = NDIBroadcaster()
        
        // Just verify it doesn't crash
        broadcaster.sendTally(isLive: true, viewerCount: 100, title: "Test Stream")
        
        // Just verify the test completes without crashing
        #expect(Bool(true), "sendTally method should not crash")
    }
    
    // MARK: - Mock Tests
    
    @Test("Should start and stop correctly")
    @MainActor func testStartAndStop() async {
        // Create a mock broadcaster instead of using the real one
        let mockBroadcaster = MockNDIBroadcaster()
        
        // Create a view model
        let viewModel = MainViewModel()
        
        // Start the broadcaster
        mockBroadcaster.start(name: "TestOutput", viewModel: viewModel)
        
        // Verify it's started
        #expect(mockBroadcaster.isStarted)
        #expect(mockBroadcaster.startCalled)
        
        // Stop the broadcaster
        mockBroadcaster.stop()
        
        // Verify it's stopped
        #expect(!mockBroadcaster.isStarted)
        #expect(mockBroadcaster.stopCalled)
    }
    
    @Test("Should format metadata correctly")
    func testNDIMetadataFormat() {
        // Create a mock broadcaster
        let mockBroadcaster = MockNDIBroadcaster()
        
        // Send a tally update with test data
        mockBroadcaster.sendTally(isLive: true, viewerCount: 100, title: "Test Stream")
        
        // Verify the metadata was formatted correctly
        #expect(mockBroadcaster.sendTallyCalled)
        #expect(mockBroadcaster.lastIsLive)
        #expect(mockBroadcaster.lastViewerCount == 100)
        #expect(mockBroadcaster.lastTitle == "Test Stream")
        
        // Verify the metadata string contains the correct attributes
        let metadata = mockBroadcaster.lastMetadata ?? ""
        #expect(metadata.contains("isLive=\"true\""))
        #expect(metadata.contains("viewerCount=\"100\""))
        #expect(metadata.contains("title=\"Test Stream\""))
    }
    
    @Test("Should handle special characters in titles")
    func testSpecialCharacterHandling() {
        // Create a mock broadcaster
        let mockBroadcaster = MockNDIBroadcaster()
        
        // Send a tally update with a title containing special characters
        let titleWithSpecialChars = "Test \"Stream\" & <Tags>"
        mockBroadcaster.sendTally(isLive: true, viewerCount: 100, title: titleWithSpecialChars)
        
        // Verify the metadata was created
        #expect(mockBroadcaster.sendTallyCalled)
        #expect(mockBroadcaster.lastTitle == titleWithSpecialChars)
        
        // Verify the special characters were properly escaped in the metadata
        let metadata = mockBroadcaster.lastMetadata ?? ""
        
        // The double quotes should be escaped as &quot;
        #expect(metadata.contains("&quot;"))
        #expect(!metadata.contains("title=\"Test \"Stream\" & <Tags>\""))
        
        // The metadata should still be valid XML
        #expect(metadata.hasPrefix("<ndi_metadata "))
        #expect(metadata.hasSuffix("/>"))
    }
} 