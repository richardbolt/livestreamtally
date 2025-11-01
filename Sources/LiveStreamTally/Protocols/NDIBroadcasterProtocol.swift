//
//  NDIBroadcasterProtocol.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import Foundation

/// Protocol for NDI broadcasting to enable dependency injection and testing
protocol NDIBroadcasterProtocol {
    /// Starts the NDI broadcaster with the given name
    /// - Parameters:
    ///   - name: The NDI source name
    ///   - viewModel: The main view model to observe
    func start(name: String, viewModel: MainViewModel) async

    /// Stops the NDI broadcaster
    func stop() async

    /// Sends a tally update via NDI metadata
    /// - Parameters:
    ///   - isLive: Whether the stream is currently live
    ///   - viewerCount: The number of viewers
    ///   - title: The stream title
    func sendTally(isLive: Bool, viewerCount: Int, title: String)

    /// Sends a video frame via NDI
    func sendFrame() async
}
