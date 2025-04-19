import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: MainViewModel
    @EnvironmentObject private var ndiViewModel: NDIViewModel
    
    init() {
        let apiKey = UserDefaults.standard.string(forKey: "youtube_api_key") ?? ""
        let channelId = UserDefaults.standard.string(forKey: "youtube_channel_id") ?? ""
        _viewModel = StateObject(wrappedValue: MainViewModel(apiKey: apiKey, channelId: channelId))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    if let error = viewModel.error {
                        Text(error)
                            .font(.title)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    if viewModel.isLive {
                        Text("🔴 LIVE")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("Viewers: \(viewModel.viewerCount)")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text(viewModel.streamTitle)
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Channel is offline")
                            .font(.system(size: 72, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(40)
            }
        }
        .onAppear {
            viewModel.startMonitoring()
            ndiViewModel.startStreaming()
            
            // Convert SwiftUI view to NSView and start frame timer
            DispatchQueue.main.async {
                if let nsView = NSApp.keyWindow?.contentView {
                    ndiViewModel.startFrameTimer(for: nsView)
                }
            }
        }
        .onDisappear {
            viewModel.stopMonitoring()
            ndiViewModel.stopStreaming()
        }
    }
}

#Preview {
    ContentView()
}