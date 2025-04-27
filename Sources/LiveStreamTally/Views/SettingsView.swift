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

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var mainViewModel: MainViewModel
    
    // Use state for the form inputs
    @State private var channelId: String
    @State private var apiKey: String
    @State private var liveCheckInterval: Double
    @State private var notLiveCheckInterval: Double
    
    // Track if we're currently processing
    @State private var isProcessing = false
    
    init() {
        // Initialize form fields from PreferencesManager
        _channelId = State(initialValue: PreferencesManager.shared.getChannelId())
        _apiKey = State(initialValue: PreferencesManager.shared.getApiKey() ?? "")
        _liveCheckInterval = State(initialValue: PreferencesManager.shared.getLiveCheckInterval())
        _notLiveCheckInterval = State(initialValue: PreferencesManager.shared.getNotLiveCheckInterval())
        
        // Create the settings view model without creating a new MainViewModel
        // The MainViewModel will be provided by the environment
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
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
                            
                            if let error = viewModel.apiKeyError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                            
                            Link("How to get a YouTube API key", destination: URL(string: "https://developers.google.com/youtube/v3/getting-started")!)
                                .font(.caption)
                                .padding(.top, 2)
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
                            
                            if let error = viewModel.channelError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                            
                            Link("How to find your YouTube Channel ID", destination: URL(string: "https://support.google.com/youtube/answer/3250431")!)
                                .font(.caption)
                                .padding(.top, 2)
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
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Live Check Interval (more compact version)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("When Live (seconds)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(liveCheckInterval))")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $liveCheckInterval, in: 5...300, step: 5)
                                .onChange(of: liveCheckInterval) { newValue in
                                    viewModel.liveCheckInterval = newValue
                                }
                        }
                        
                        // Not Live Check Interval (more compact version)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("When Not Live (seconds)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(notLiveCheckInterval))")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $notLiveCheckInterval, in: 5...300, step: 5)
                                .onChange(of: notLiveCheckInterval) { newValue in
                                    viewModel.notLiveCheckInterval = newValue
                                }
                        }
                        
                        // Description for both intervals
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YouTube API Quota Information:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                            
                            Text("• Each check when live uses 1 quota unit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("• Each check when not live uses 2 quota units")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("• Default quota limit is 10,000 units per day")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("Lower values mean more frequent checks but higher quota usage.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Polling Intervals")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 8)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)  // Keep scrolling enabled to handle variable content height
            
            // Bottom button area
            HStack {
                Spacer()
                
                if isProcessing || viewModel.isProcessing {
                    ProgressView()
                        .padding(.trailing, 8)
                }
                
                Button("Done") {
                    isProcessing = true
                    
                    Task {
                        // Save settings using the new ViewModel
                        await viewModel.saveSettings(
                            channelId: channelId,
                            apiKey: apiKey
                        )
                        
                        // Always start monitoring to refresh the state
                        await mainViewModel.startMonitoring()
                        
                        isProcessing = false
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || viewModel.isProcessing)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 400, height: 650)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .environmentObject(MainViewModel())
} 