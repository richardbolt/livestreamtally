//
//  AppDelegate.swift
//  LiveStreamTally
//
//  Created by Richard Bolt
//  Copyright © 2025 Richard Bolt. All rights reserved.
//
//  This file is part of LiveStreamTally, released under the MIT License.
//  See the LICENSE file for details.
//

import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // View model references (set by LiveStreamTallyApp after initialization)
    var mainViewModel: MainViewModel?
    var ndiViewModel: NDIViewModel?

    // Track whether NDI has been started
    private var ndiStarted = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        Logger.debug("applicationWillFinishLaunching", category: .app)
        // Early activation to bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.debug("applicationDidFinishLaunching", category: .app)

        // Find the window created by WindowGroup
        guard let window = NSApp.windows.first else {
            Logger.error("No window found in applicationDidFinishLaunching", category: .app)
            return
        }

        Logger.debug("Found window, configuring...", category: .app)

        // Set ourselves as the window delegate
        window.delegate = self

        // Configure window properties
        window.title = "Live Stream Tally"
        window.aspectRatio = NSSize(width: 16, height: 9)

        // Ensure window is visible and frontmost
        window.makeKeyAndOrderFront(nil)
        window.center()

        // Start NDI now that window is confirmed to exist
        startNDIIfReady()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Logger.debug("applicationShouldHandleReopen: \(flag)", category: .app)

        if !flag {
            // If no visible windows, find and show the main window
            for window in sender.windows {
                if window.title == "Live Stream Tally" {
                    window.makeKeyAndOrderFront(self)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    break
                }
            }
        } else {
            // If windows are just hidden, activate the app
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("Application will terminate, cleaning up resources", category: .app)

        // Clean up NDI resources
        ndiViewModel?.prepareForDeinit()
    }

    // MARK: - NDI Management

    /// Start NDI streaming once both view models are available
    func startNDIIfReady() {
        guard !ndiStarted else {
            Logger.debug("NDI already started, skipping", category: .app)
            return
        }

        guard let mainViewModel = mainViewModel,
              let ndiViewModel = ndiViewModel else {
            Logger.warning("View models not yet available for NDI start", category: .app)
            return
        }

        Logger.info("Starting NDI streaming", category: .app)

        // Ensure NDI view model has reference to main view model
        ndiViewModel.setupWithMainViewModel(mainViewModel)

        // Start streaming
        ndiViewModel.startStreaming()

        ndiStarted = true
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Logger.debug("Main window closing", category: .app)

        // Stop NDI streaming when the main window is closed
        ndiViewModel?.stopStreaming()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Logger.debug("applicationShouldTerminateAfterLastWindowClosed called", category: .app)
        return true
    }
}
