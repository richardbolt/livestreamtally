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
                            Text("API Key")
                                .foregroundStyle(.secondary)
                            SecureField("", text: $apiKey)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .help("Your YouTube Data API v3 key")
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Channel ID")
                                .foregroundStyle(.secondary)
                            TextField("", text: $channelId)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .help("Your YouTube channel ID")
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
        .frame(width: 440, height: 300)
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