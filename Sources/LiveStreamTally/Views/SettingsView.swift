//
//  SettingsView.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import SwiftUI
import os

@MainActor
class SettingsViewModel: ObservableObject {
    private var youtubeService: YouTubeService?
    
    init() {
        if let apiKey = UserDefaults.standard.string(forKey: "youtube_api_key") {
            youtubeService = try? YouTubeService(apiKey: apiKey)
        }
    }
    
    func resolveAndCacheChannelId(_ channelId: String) async {
        guard let service = youtubeService else { return }
        
        do {
            let (resolvedId, uploadPlaylistId) = try await service.resolveChannelIdentifier(channelId)
            UserDefaults.standard.set(resolvedId, forKey: "youtube_channel_id_cached")
            UserDefaults.standard.set(uploadPlaylistId, forKey: "youtube_upload_playlist_id")
            Logger.debug("Cached channel ID and playlist ID", category: .main)
        } catch {
            Logger.error("Failed to resolve channel ID: \(error.localizedDescription)", category: .main)
        }
    }
}

struct SettingsView: View {
    @AppStorage("youtube_channel_id") private var channelId = ""
    @AppStorage("youtube_channel_id_cached") private var cachedChannelId = ""
    @AppStorage("youtube_upload_playlist_id") private var uploadPlaylistId = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var mainViewModel: MainViewModel
    
    // Store initial values to detect changes
    @State private var apiKey = ""
    private let initialApiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
    private let initialChannelId = UserDefaults.standard.string(forKey: "youtube_channel_id") ?? ""
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("API Key")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(action: {
                                    NSWorkspace.shared.open(URL(string: "https://console.cloud.google.com/apis/credentials")!)
                                }) {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Click to open Google Cloud Console to create an API key")
                            }
                            
                            SecureField("", text: $apiKey)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .help("""
                                To get a YouTube Data API v3 key:
                                1. Go to console.cloud.google.com
                                2. Create a new project (or select existing)
                                3. Navigate to APIs & Services > Library
                                4. Search for and enable "YouTube Data API v3"
                                5. Go to Credentials and create an API key
                                6. Copy the key and paste it here
                                """)
                            
                            Link("How to get a YouTube API key", destination: URL(string: "https://developers.google.com/youtube/v3/getting-started")!)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Channel ID or Handle")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(action: {
                                    NSWorkspace.shared.open(URL(string: "https://www.youtube.com/account_advanced")!)
                                }) {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Click to go to YouTube Advanced account settings to find your Channel ID")
                            }
                            
                            TextField("", text: $channelId)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .help("Your YouTube channel ID from your channel's advanced settings page")
                            
                            Link("How to find your YouTube Channel ID", destination: URL(string: "https://support.google.com/youtube/answer/3250431")!)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("YouTube API Configuration")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 8)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            
            // Bottom button area
            HStack {
                Spacer()
                Button("Done") {
                    Task {
                        let apiKeyChanged = apiKey != initialApiKey
                        let channelIdChanged = channelId != initialChannelId
                        
                        if apiKeyChanged {
                            mainViewModel.updateApiKey(apiKey)
                        }
                        
                        if channelIdChanged {
                            // Only resolve and cache if the channel ID changed
                            await viewModel.resolveAndCacheChannelId(channelId)
                            mainViewModel.updateChannelId(channelId)
                        }
                        
                        // Only restart monitoring if something changed
                        if apiKeyChanged || channelIdChanged {
                            mainViewModel.startMonitoring()
                        }
                        
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 440, height: 340)  // Increased height to accommodate new elements
        .preferredColorScheme(.dark)
        .onAppear {
            apiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MainViewModel())
} 