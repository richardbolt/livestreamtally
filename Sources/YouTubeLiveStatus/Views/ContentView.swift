import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: MainViewModel
    @EnvironmentObject private var ndiViewModel: NDIViewModel
    private let baseWidth: CGFloat = 1280
    private let baseHeight: CGFloat = 720
    
    init() {
        let apiKey = UserDefaults.standard.string(forKey: "youtube_api_key") ?? ""
        _viewModel = StateObject(wrappedValue: MainViewModel(apiKey: apiKey))
    }
    
    private func startMonitoring() {
        viewModel.startMonitoring()
    }
    
    private func stopMonitoring() {
        viewModel.stopMonitoring()
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
            startMonitoring()
            DispatchQueue.main.async {
                ndiViewModel.startStreaming()
            }
        }
        .onDisappear {
            stopMonitoring()
            ndiViewModel.stopStreaming()
        }
        .background(
            NDIBroadcastView(viewModel: viewModel)
                .frame(width: baseWidth, height: baseHeight)
                .hidden()
        )
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
                        .foregroundColor(.white)
                }
                .padding(.vertical, geometry.size.height * 0.05)
                
                if viewModel.isLive {
                    Text("Viewers: \(viewModel.viewerCount)")
                        .font(.system(size: geometry.size.width * 0.04))
                        .foregroundColor(.gray)
                    
                    Text(viewModel.title)
                        .font(.system(size: geometry.size.width * 0.05))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct NDIBroadcastView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
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
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    
                    statusView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var statusView: some View {
        VStack(alignment: .center, spacing: 24) {
            HStack(spacing: 24) {
                Circle()
                    .fill(viewModel.isLive ? Color.red : Color.gray)
                    .frame(width: 36, height: 36)
                Text(viewModel.isLive ? "ON AIR" : "OFF AIR")
                    .font(.system(size: 200, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 16)
            
            if viewModel.isLive {
                Text("Viewers: \(viewModel.viewerCount)")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                
                Text(viewModel.title)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    ContentView()
} 