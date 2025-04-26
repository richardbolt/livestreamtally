//
//  NDIViewModel.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation
import SwiftUI
import AppKit
import os

@MainActor
class NDIViewModel: ObservableObject {
    @Published var isStreaming = false
    @Published var error: String?
    
    private let broadcaster = NDIBroadcaster()
    private var timer: Timer?
    private let mainViewModel: MainViewModel
    
    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
    }
    
    @MainActor
    func startStreaming() {
        guard !isStreaming else { return }
        
        Logger.info("Starting NDI streaming", category: .app)
        
        broadcaster.start(name: "YouTube Live Status", viewModel: mainViewModel)
        isStreaming = true
        
        // Start a timer to send frames
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.broadcaster.sendFrame()
            }
        }
    }
    
    @MainActor
    func stopStreaming() {
        guard isStreaming else { return }
        
        Logger.info("Stopping NDI streaming", category: .app)
        
        timer?.invalidate()
        timer = nil
        broadcaster.stop()
        isStreaming = false
    }
    
    @MainActor
    func updateTally() {
        guard isStreaming else { return }
        
        broadcaster.sendTally(
            isLive: mainViewModel.isLive,
            viewerCount: mainViewModel.viewerCount,
            title: mainViewModel.title
        )
    }
    
    deinit {
        // Capture a reference to the broadcaster outside of the task
        // to avoid potential memory issues
        let broadcaster = self.broadcaster
        
        // Use Task to properly clean up resources on the MainActor
        Task { @MainActor [weak self] in
            self?.stopStreaming()
            broadcaster.stop()
            Logger.info("NDIViewModel deinitialized", category: .app)
        }
    }
} 