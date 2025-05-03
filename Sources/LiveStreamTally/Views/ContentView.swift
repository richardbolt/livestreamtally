//
//  ContentView.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var ndiViewModel: NDIViewModel
    private let baseWidth: CGFloat = 1280
    private let baseHeight: CGFloat = 720
    @State private var ndiObserver: NSObjectProtocol? // Store observer reference

    private func startMonitoring() async {
        await viewModel.startMonitoring()
    }
    
    private func stopMonitoring() async {
        await viewModel.stopMonitoring()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(2.0)
                    } else {
                        if let error = viewModel.error {
                            Text(error)
                                .font(.system(size: geometry.size.width * 0.03))
                                .foregroundColor(.red)
                        }
                        
                        statusView
                    }
                }
                .padding()
                .frame(
                    width: min(geometry.size.width, baseWidth),
                    height: min(geometry.size.height, baseHeight)
                )
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .onAppear {
            Task { @MainActor in
                Logger.debug("ContentView onAppear", category: .app)
                
                // NDI setup/start is now handled by AppDelegate after window creation
                
                // Start YouTube monitoring
                await startMonitoring()
            }
        }
        .onDisappear {
            // Remove notification observer if it exists
            if let observer = ndiObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            Task {
                await stopMonitoring()
            }
        }
    }
    
    private var statusView: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                HStack(spacing: geometry.size.width * 0.03) {
                    Circle()
                        .fill(viewModel.isLive ? Color.red : Color.gray)
                        .frame(width: geometry.size.width * 0.05, height: geometry.size.width * 0.05)
                    Text(viewModel.isLive ? "ON AIR" : "OFF AIR")
                        .font(.system(size: geometry.size.width * 0.15, weight: .bold))
                        .foregroundColor(viewModel.isLive ? .red : .white)
                }
                .padding(.vertical, geometry.size.height * 0.03)
                
                // Time display
                Text(viewModel.currentTime)
                    .font(.system(size: geometry.size.width * 0.08, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.isLive ? .red : .gray)
                    .padding(.bottom, geometry.size.height * 0.03)
                
                // Livestream Title display
                Text(viewModel.title)
                    .font(.system(size: geometry.size.width * 0.05))
                    .foregroundColor(viewModel.isLive ? .white : .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                // Livestream current viewer count
                if viewModel.isLive {
                    Text("Viewers: \(viewModel.viewerCount)")
                        .font(.system(size: geometry.size.width * 0.04))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
} 