import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @EnvironmentObject private var ndiViewModel: NDIViewModel
    private let baseWidth: CGFloat = 1280
    private let baseHeight: CGFloat = 720
    /*
    init() {
        let apiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
        _viewModel = StateObject(wrappedValue: MainViewModel(apiKey: apiKey))
    }
    */
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
                .padding(.vertical, geometry.size.height * 0.05)
                
                Text(viewModel.title)
                    .font(.system(size: geometry.size.width * 0.05))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
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