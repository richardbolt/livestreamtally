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
    @AppStorage("youtube_api_key") private var apiKey = ""
    @AppStorage("youtube_channel_id") private var channelId = ""
    @AppStorage("youtube_channel_id_cached") private var cachedChannelId = ""
    @AppStorage("youtube_upload_playlist_id") private var uploadPlaylistId = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var mainViewModel: MainViewModel
    
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
                        // Update the main view model with new settings
                        mainViewModel.updateApiKey(apiKey)
                        mainViewModel.updateChannelId(channelId)
                        
                        // Clear cached playlist ID when channel changes
                        if channelId != cachedChannelId {
                            UserDefaults.standard.removeObject(forKey: "youtube_upload_playlist_id")
                        }
                        
                        // Resolve and cache the channel ID
                        await viewModel.resolveAndCacheChannelId(channelId)
                        
                        // Start monitoring with new settings
                        mainViewModel.startMonitoring()
                        
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
    }
}

#Preview {
    SettingsView()
        .environmentObject(MainViewModel())
} 