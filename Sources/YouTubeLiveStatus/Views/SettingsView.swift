import SwiftUI

struct SettingsView: View {
    @AppStorage("youtube_api_key") private var apiKey = ""
    @AppStorage("youtube_channel_id") private var channelId = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
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
                    dismiss()
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
} 