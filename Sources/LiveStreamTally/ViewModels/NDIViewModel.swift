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
@preconcurrency import Combine  // Mark Combine as pre-concurrency to handle Sendable warnings
import os

@MainActor
class NDIViewModel: ObservableObject {
    @Published var isStreaming = false
    @Published var error: String?
    
    private let broadcaster = NDIBroadcaster()
    private var framePublisher: AnyCancellable?
    private var mainViewModel: MainViewModel?
    
    // Add cancellables set to store subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(mainViewModel: MainViewModel? = nil) {
        if let mainViewModel = mainViewModel {
            self.mainViewModel = mainViewModel
        }
        
        // Set up subscriptions to mainViewModel publishers for tally updates
        setupTallySubscriptions()
    }
    
    // Set up subscriptions to MainViewModel's published properties
    private func setupTallySubscriptions() {
        guard let mainViewModel = mainViewModel else { return }
        
        // Combine the three relevant properties into a single publisher
        mainViewModel.$isLive
            .combineLatest(mainViewModel.$viewerCount, mainViewModel.$title)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main) // Prevent excessive updates
            .sink { [weak self] (isLive, viewerCount, title) in
                guard let self = self else { return }
                // Only update tally if we're streaming
                if self.isStreaming {
                    self.updateTally()
                }
            }
            .store(in: &cancellables)
    }
    
    func setupWithMainViewModel(_ mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        // Set up subscriptions after mainViewModel is set
        setupTallySubscriptions()
    }
    
    @MainActor
    func startStreaming() {
        guard !isStreaming else { return }
        guard let mainViewModel = mainViewModel else {
            Logger.error("Cannot start NDI streaming: mainViewModel is nil", category: .app)
            return
        }
        
        Logger.info("Starting NDI streaming", category: .app)
        
        Task {
            await broadcaster.start(name: "Live Stream Tally", viewModel: mainViewModel)
        }
        isStreaming = true

        // Use Combine publisher for more efficient frame sending
        framePublisher = Timer.publish(every: 1.0/30.0, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.broadcaster.sendFrame()
                }
            }
        
        // Send initial tally data when starting stream
        updateTally()
    }
    
    @MainActor
    func stopStreaming() {
        guard isStreaming else { return }
        
        Logger.info("Stopping NDI streaming", category: .app)
        
        // Cancel frame publisher
        framePublisher?.cancel()
        framePublisher = nil
        
        // Stop the broadcaster
        Task {
            await broadcaster.stop()
        }

        // Update state
        isStreaming = false
    }
    
    @MainActor
    func updateTally() {
        guard isStreaming else { return }
        
        Logger.debug("Updating NDI tally with isLive: \(mainViewModel!.isLive), viewers: \(mainViewModel!.viewerCount)", category: .app)
        
        broadcaster.sendTally(
            isLive: mainViewModel!.isLive,
            viewerCount: mainViewModel!.viewerCount,
            title: mainViewModel!.title
        )
    }
}

// MARK: - MainActor isolated extension for cleanup
@MainActor extension NDIViewModel {
    // Cleanup method called before deinitialization
    func prepareForDeinit() {
        // Cancel all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Stop streaming if needed
        if isStreaming {
            stopStreaming()
        }
        
        Logger.info("NDIViewModel prepared for deinitialization", category: .app)
    }
} 