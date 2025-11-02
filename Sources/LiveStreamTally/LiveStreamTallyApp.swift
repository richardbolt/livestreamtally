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
    @StateObject private var mainViewModel: MainViewModel
    @StateObject private var ndiViewModel: NDIViewModel

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        Logger.debug("LiveStreamTallyApp init", category: .app)

        // Initialize MainViewModel
        let apiKey = KeychainManager.shared.retrieveAPIKey() ?? ""
        let mainVM = MainViewModel(apiKey: apiKey)
        _mainViewModel = StateObject(wrappedValue: mainVM)

        // Initialize NDIViewModel (without mainViewModel reference initially)
        let ndiVM = NDIViewModel()
        _ndiViewModel = StateObject(wrappedValue: ndiVM)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 360)
                .frame(maxWidth: 1920, maxHeight: 1080)
                .environmentObject(mainViewModel)
                .environmentObject(ndiViewModel)
                .onAppear {
                    // Pass view models to AppDelegate and start NDI
                    // This happens after WindowGroup creates the window
                    appDelegate.mainViewModel = mainViewModel
                    appDelegate.ndiViewModel = ndiViewModel
                    appDelegate.startNDIIfReady()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Live Stream Tally") {
                    // Get the main bundle info dictionary
                    let infoDict = Bundle.main.infoDictionary
                    let buildNumber = infoDict?["CFBundleVersion"] as? String ?? "Unknown"
                    
                    // Get commit hash from Info.plist (set during build)
                    let gitCommitHash = infoDict?["GitCommitHash"] as? String ?? "unknown"
                    
                    // Format the build string including commit hash
                    let buildString = "Build \(buildNumber)-\(gitCommitHash)"
                    let ndiCredits = "NDI® is a registered trademark of Vizrt NDI AB"
                    let combinedCredits = "\(buildString)\n\n\(ndiCredits)"
                                    
                    // Create paragraph style for centering
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    
                    // Define attributes for the credits text
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small)), // Match small system font size
                        .paragraphStyle: paragraphStyle
                    ]
                    
                    // Prepare options for the about panel
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [
                        // Don't set .applicationVersion, let it default from Info.plist
                        // Set the combined build string and NDI text as credits with attributes
                        .credits: NSAttributedString(string: combinedCredits, attributes: attributes)
                    ]
                    
                    // Add application name if available
                    if let appName = infoDict?["CFBundleName"] as? String {
                        options[NSApplication.AboutPanelOptionKey.applicationName] = appName
                    }
                    
                    // Add copyright if available
                    if let copyright = infoDict?["NSHumanReadableCopyright"] as? String {
                        // Use rawValue for the Copyright key
                        options[NSApplication.AboutPanelOptionKey(rawValue: "Copyright")] = copyright // Keep copyright separate
                    }

                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
            
            CommandGroup(replacing: .systemServices) {}  // Remove Services menu

            // Replace the default Help menu item
            CommandGroup(replacing: .help) {
                Button("Live Stream Tally Help") {
                    if let url = URL(string: "https://www.richardbolt.com/live-stream-tally/") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(mainViewModel)
        }
    }
}

