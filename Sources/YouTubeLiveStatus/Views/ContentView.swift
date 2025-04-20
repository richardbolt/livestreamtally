import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: MainViewModel
    @EnvironmentObject private var ndiViewModel: NDIViewModel
    
    init() {
        let apiKey = UserDefaults.standard.string(forKey: "youtube_api_key") ?? ""
        _viewModel = StateObject(wrappedValue: MainViewModel(apiKey: apiKey))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 1280 // Base scale factor
            
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20 * scale) {
                    if let error = viewModel.error {
                        Text(error)
                            .font(.system(size: 24 * scale))
                            .foregroundColor(.red)
                            .padding(20 * scale)
                    }
                    
                    if viewModel.isLive {
                        Text("🔴 ON AIR")
                            .font(.system(size: 200 * scale, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("Viewers: \(viewModel.viewerCount)")
                            .font(.system(size: 48 * scale))
                            .foregroundColor(.white)
                        
                        Text(viewModel.title)
                            .font(.system(size: 36 * scale))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40 * scale)
                    } else {
                        Text("⚪ OFF AIR")
                            .font(.system(size: 200 * scale, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(40 * scale)
            }
        }
        .aspectRatio(16.0/9.0, contentMode: .fit)
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