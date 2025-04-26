//
//  AppState.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var isLive: Bool = false
    @Published var viewerCount: Int = 0
    @Published var streamTitle: String = ""
    @Published var lastUpdated: Date = Date()
    @Published var refreshInterval: TimeInterval = 60 // Default 1 minute
    @Published var apiKey: String = ""
    @Published var channelId: String = ""
    
    // Error handling
    @Published var errorMessage: String?
    @Published var isError: Bool = false
} 