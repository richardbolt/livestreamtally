//
//  NDISpy.swift
//  LiveStreamTallyTests
//
//  Test infrastructure for NDI broadcasting testing
//

import Foundation
@testable import LiveStreamTally

/// Tally event for tracking NDI state changes
enum TallyEvent: Equatable {
    case on(viewerCount: Int, title: String)
    case off

    static func == (lhs: TallyEvent, rhs: TallyEvent) -> Bool {
        switch (lhs, rhs) {
        case (.off, .off):
            return true
        case let (.on(lhsCount, lhsTitle), .on(rhsCount, rhsTitle)):
            return lhsCount == rhsCount && lhsTitle == rhsTitle
        default:
            return false
        }
    }
}

/// NDI spy for testing NDI integration without hardware
final class NDISpy: NDIBroadcasterProtocol, @unchecked Sendable {
    /// Track whether broadcaster is started
    var isStarted = false

    /// Track all tally events
    var tallyEvents: [TallyEvent] = []

    /// Track method calls
    var startCalled = false
    var stopCalled = false
    var sendTallyCalled = false
    var sendFrameCalled = false

    /// Last values sent
    var lastIsLive: Bool?
    var lastViewerCount: Int?
    var lastTitle: String?
    var lastMetadata: String?

    /// Captured start parameters
    var lastStartName: String?
    var lastStartViewModel: MainViewModel?

    init() {}

    func start(name: String, viewModel: MainViewModel) async {
        startCalled = true
        isStarted = true
        lastStartName = name
        lastStartViewModel = viewModel
    }

    func stop() async {
        stopCalled = true
        isStarted = false
    }

    func sendTally(isLive: Bool, viewerCount: Int, title: String) {
        sendTallyCalled = true
        lastIsLive = isLive
        lastViewerCount = viewerCount
        lastTitle = title

        // Build metadata string like real implementation
        var metadata = "<ndi_metadata "
        metadata += "isLive=\"\(isLive ? "true" : "false")\" "
        metadata += "viewerCount=\"\(viewerCount)\" "
        metadata += "title=\"\(title.replacingOccurrences(of: "\"", with: "&quot;"))\" "
        metadata += "/>"
        lastMetadata = metadata

        // Track event
        if isLive {
            tallyEvents.append(.on(viewerCount: viewerCount, title: title))
        } else {
            tallyEvents.append(.off)
        }
    }

    func sendFrame() async {
        sendFrameCalled = true
    }

    /// Reset the spy state
    func reset() {
        isStarted = false
        tallyEvents = []
        startCalled = false
        stopCalled = false
        sendTallyCalled = false
        sendFrameCalled = false
        lastIsLive = nil
        lastViewerCount = nil
        lastTitle = nil
        lastMetadata = nil
        lastStartName = nil
        lastStartViewModel = nil
    }
}
