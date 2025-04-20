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
                        Text("🔴 ON AIR")
                            .font(.system(size: 100, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("Viewers: \(viewModel.viewerCount)")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text(viewModel.title)
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("⚪ OFF AIR")
                            .font(.system(size: 100, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(40)
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