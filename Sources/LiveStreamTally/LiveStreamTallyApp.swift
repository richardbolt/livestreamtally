//
//  LiveStreamTallyApp.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import SwiftUI

@main
struct LiveStreamTallyApp: App {
    // Add a shared static instance of MainViewModel to prevent recreation
    private static let sharedMainViewModel: MainViewModel = {
        Logger.debug("Creating shared MainViewModel instance", category: .app)
        let apiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
        return MainViewModel(apiKey: apiKey)
    }()
    
    // Add a reference to the lifecycle handler
    private let lifecycleHandler = AppLifecycleHandler()
    
    @StateObject private var mainViewModel: MainViewModel
    @StateObject private var ndiViewModel: NDIViewModel
    
    init() {
        // Use the shared instance instead of creating a new one each time
        _mainViewModel = StateObject(wrappedValue: LiveStreamTallyApp.sharedMainViewModel)
        _ndiViewModel = StateObject(wrappedValue: NDIViewModel(mainViewModel: LiveStreamTallyApp.sharedMainViewModel))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 360)
                .frame(maxWidth: 1920, maxHeight: 1080)
                .environmentObject(mainViewModel)
                .environmentObject(ndiViewModel)
                .onAppear {
                    // Ensure window is visible and properly sized
                    if let window = NSApp.windows.first(where: { $0.title == "Live Stream Tally" }) {
                        window.center()
                        window.makeKeyAndOrderFront(nil)
                        
                        // Set initial size to 1280x720 (16:9)
                        window.setFrame(NSRect(x: window.frame.origin.x,
                                             y: window.frame.origin.y,
                                             width: 1280,
                                             height: 720),
                                      display: true)
                        
                        // Make sure window appears in dock
                        window.collectionBehavior = [.managed]
                        
                        // Enforce 16:9 aspect ratio
                        window.aspectRatio = NSSize(width: 16, height: 9)
                        
                        // Set window delegate to handle window closing
                        window.delegate = WindowDelegate.shared
                    }
                    
                    // Set up the NDI view model in our lifecycle handler
                    lifecycleHandler.setupWithNDIViewModel(ndiViewModel)
                }
                .onDisappear {
                    // Stop NDI streaming when window is closed
                    ndiViewModel.stopStreaming()
                }
        }
        //.windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Live Stream Tally") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "NDI® is a registered trademark of Vizrt NDI AB"
                            )
                        ]
                    )
                }
            }
            
            CommandGroup(replacing: .systemServices) {}  // Remove Services menu
        }
        
        Settings {
            SettingsView()
                .environmentObject(mainViewModel)
        }
    }
}

// Window delegate to handle window closing
@MainActor
class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        // Prepare for app termination in a clean way
        Logger.info("Main window will close, preparing for app termination", category: .app)
        
        // Give time for any outstanding operations to complete properly
        // before terminating the application
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Exit the app when the main window is closed
            NSApplication.shared.terminate(nil)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Class to handle app lifecycle events and resource cleanup
@MainActor
class AppLifecycleHandler: NSObject {
    // Reference to the NDI view model to clean up
    private weak var ndiViewModel: NDIViewModel?
    
    override init() {
        super.init()
        
        // Register for app termination notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        Logger.debug("AppLifecycleHandler initialized", category: .app)
    }
    
    // Set up with NDI view model
    func setupWithNDIViewModel(_ viewModel: NDIViewModel) {
        self.ndiViewModel = viewModel
        Logger.debug("AppLifecycleHandler configured with NDIViewModel", category: .app)
    }
    
    // Handle app termination
    @objc private func handleAppWillTerminate() {
        Logger.info("Application will terminate, cleaning up resources", category: .app)
        
        // Clean up NDI view model
        if let ndiViewModel = ndiViewModel {
            ndiViewModel.prepareForDeinit()
            Logger.info("NDIViewModel cleanup completed", category: .app)
        } else {
            Logger.warning("NDIViewModel not available for cleanup", category: .app)
        }
    }
    
    deinit {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
    }
}

