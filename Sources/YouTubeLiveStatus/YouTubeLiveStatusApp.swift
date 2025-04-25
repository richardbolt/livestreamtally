//
//  YouTubeLiveStatusApp.swift
//  YouTubeLiveStatus
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of YouTubeLiveStatus, released under the MIT License.
//  See the LICENSE file for details.
//

import SwiftUI

@main
struct YouTubeLiveStatusApp: App {
    @StateObject private var mainViewModel: MainViewModel
    @StateObject private var ndiViewModel: NDIViewModel
    
    init() {
        let apiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
        let mainVM = MainViewModel(apiKey: apiKey)
        _mainViewModel = StateObject(wrappedValue: mainVM)
        _ndiViewModel = StateObject(wrappedValue: NDIViewModel(mainViewModel: mainVM))
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
                    if let window = NSApp.windows.first(where: { $0.title == "YouTube Live Status" }) {
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
                Button("About YouTube Live Status") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "NDI® is a registered trademark of Vizrt Group."
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
class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        // Exit the app when the main window is closed
        NSApplication.shared.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

