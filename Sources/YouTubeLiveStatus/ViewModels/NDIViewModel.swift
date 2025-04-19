import Foundation
import SwiftUI
import AppKit
import os

@MainActor
class NDIViewModel: ObservableObject {
    @Published var isEnabled = false
    @Published var error: Error?
    @Published var sourceName: String = "YouTube Live Status"
    
    private let broadcaster = NDIBroadcaster()
    private var frameTimer: Timer?
    private var view: NSView?
    
    init(name: String = "YouTube Live Status") {
        self.sourceName = name
        Logger.info("NDIViewModel initialized", category: .app)
    }
    
    func startStreaming() {
        Logger.info("Starting NDI broadcast", category: .app)
        broadcaster.start(name: sourceName)
        isEnabled = true
    }
    
    func stopStreaming() {
        Logger.info("Stopping NDI broadcast", category: .app)
        broadcaster.stop()
        isEnabled = false
        stopFrameTimer()
    }
    
    func updateTally(isLive: Bool, viewerCount: Int, title: String) {
        Logger.debug("Updating NDI tally", category: .app)
        broadcaster.sendTally(isLive: isLive, viewerCount: viewerCount, title: title)
    }
    
    func startFrameTimer(for view: NSView) {
        Logger.debug("Starting frame timer", category: .app)
        self.view = view
        
        // Create a weak reference to self to avoid retain cycles
        weak var weakSelf = self
        
        // Run the timer on the main thread since we're updating UI
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            Task { @MainActor in
                guard let self = weakSelf else { return }
                if let view = self.view {
                    self.broadcaster.sendFrame(view)
                }
            }
        }
    }
    
    nonisolated func stopFrameTimer() {
        DispatchQueue.main.async {
            Logger.debug("Stopping frame timer", category: .app)
            self.frameTimer?.invalidate()
            self.frameTimer = nil
            self.view = nil
        }
    }
    
    deinit {
        // Stop streaming synchronously since we're already on the main thread
        stopFrameTimer()
        broadcaster.stop()
        Logger.info("NDIViewModel deinitialized", category: .app)
    }
} 