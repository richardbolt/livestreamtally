//
//  Mocks.swift
//  LiveStreamTallyTests
//
//  Created as a test scaffolding
//

import Foundation
@testable import LiveStreamTally

// MARK: - Mock YouTube Service

// We'll create an independent mock that doesn't rely on the actual service
@MainActor
class MockYouTubeService {
    var mockLiveStatus: LiveStatus?
    var mockError: Error?
    var resolvedChannelInfo: (String, String)?
    
    // Track method calls
    var checkLiveStatusCalled = false
    var resolveChannelIdentifierCalled = false
    var clearCacheCalled = false
    
    init() {}
    
    func checkLiveStatus(channelId: String, uploadPlaylistId: String) async throws -> LiveStatus {
        checkLiveStatusCalled = true
        
        if let error = mockError {
            throw error
        }
        
        return mockLiveStatus ?? LiveStatus(isLive: false, viewerCount: 0, title: "Mock Stream", videoId: "mock123")
    }
    
    func resolveChannelIdentifier(_ identifier: String) async throws -> (String, String) {
        resolveChannelIdentifierCalled = true
        
        if let error = mockError {
            throw error
        }
        
        return resolvedChannelInfo ?? ("UC12345", "UU12345")
    }
    
    func clearCache() async {
        clearCacheCalled = true
    }
}

// MARK: - Mock NDI Broadcaster

class MockNDIBroadcaster {
    var isStarted = false
    var lastMetadata: String?
    var lastIsLive = false
    var lastViewerCount = 0
    var lastTitle = ""
    
    // Track method calls
    var startCalled = false
    var stopCalled = false
    var sendTallyCalled = false
    var sendFrameCalled = false
    
    init() {}
    
    func start(name: String, viewModel: MainViewModel) {
        startCalled = true
        isStarted = true
    }
    
    func stop() {
        stopCalled = true
        isStarted = false
    }
    
    func sendTally(isLive: Bool, viewerCount: Int, title: String) {
        sendTallyCalled = true
        lastIsLive = isLive
        lastViewerCount = viewerCount
        lastTitle = title
        
        // Build the metadata string like the real implementation
        var metadata = "<ndi_metadata "
        metadata += "isLive=\"\(isLive ? "true" : "false")\" "
        metadata += "viewerCount=\"\(viewerCount)\" "
        metadata += "title=\"\(title.replacingOccurrences(of: "\"", with: "&quot;"))\" "
        metadata += "/>"
        
        lastMetadata = metadata
    }
    
    func sendFrame() {
        sendFrameCalled = true
    }
}

// MARK: - Mock Preferences Manager

class MockPreferencesManager {
    var channelId = ""
    var cachedChannelId = ""
    var uploadPlaylistId = ""
    var apiKey = ""
    var liveRefreshInterval: TimeInterval = 30.0
    var notLiveRefreshInterval: TimeInterval = 60.0
    var ndiOutputName = "LiveStreamTally"
    var ndiEnabled = false
    
    func getChannelId() -> String {
        return channelId
    }
    
    func setChannelId(_ value: String) {
        channelId = value
        NotificationCenter.default.post(name: PreferencesManager.Notifications.channelChanged, object: nil)
    }
    
    func getApiKey() -> String? {
        return apiKey
    }
    
    func setApiKey(_ value: String) {
        apiKey = value
        NotificationCenter.default.post(name: PreferencesManager.Notifications.apiKeyChanged, object: nil)
    }
    
    func getLiveCheckInterval() -> TimeInterval {
        return liveRefreshInterval
    }
    
    func getNotLiveCheckInterval() -> TimeInterval {
        return notLiveRefreshInterval
    }
    
    func updateIntervals(liveInterval: TimeInterval, notLiveInterval: TimeInterval) {
        liveRefreshInterval = liveInterval
        notLiveRefreshInterval = notLiveInterval
        NotificationCenter.default.post(name: PreferencesManager.Notifications.intervalChanged, object: nil)
    }
    
    func getNDIOutputName() -> String {
        return ndiOutputName
    }
    
    func setNDIOutputName(_ value: String) {
        ndiOutputName = value
    }
    
    func isNDIEnabled() -> Bool {
        return ndiEnabled
    }
    
    func setNDIEnabled(_ value: Bool) {
        ndiEnabled = value
    }
} 