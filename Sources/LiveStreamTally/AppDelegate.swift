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
    // View model references (set by LiveStreamTallyApp during initialization)
    var mainViewModel: MainViewModel?
    var ndiViewModel: NDIViewModel?

    // Track whether NDI has been started
    private var ndiStarted = false

    // Track whether window setup has completed
    private var windowSetupCompleted = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        Logger.debug("applicationWillFinishLaunching", category: .app)
        // Early activation to bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
        Logger.debug("App activation requested in applicationWillFinishLaunching", category: .app)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.debug("applicationDidFinishLaunching - isActive: \(NSApp.isActive), windows: \(NSApp.windows.count)", category: .app)

        // CRITICAL: Ensure app activation policy is set to regular
        // This is essential for Login Item launches to show window properly
        NSApp.setActivationPolicy(.regular)

        // Get view models - they must be available at this point
        guard let mainViewModel = mainViewModel, let ndiViewModel = ndiViewModel else {
            Logger.error("View models not available in AppDelegate", category: .app)
            return
        }

        // Check if a window already exists (normal launch)
        if NSApp.windows.first != nil {
            Logger.debug("Found existing window, configuring...", category: .app)
            // Configure the existing window
            configureWindow()
        } else {
            // CRITICAL: When launched as Login Item, SwiftUI's WindowGroup doesn't
            // create a window automatically. We must manually create it.
            Logger.info("No window found (Login Item launch), manually creating window", category: .app)

            // Manually create the window with NSHostingView
            let contentView = ContentView()
                .environmentObject(mainViewModel)
                .environmentObject(ndiViewModel)

            let hostingView = NSHostingView(rootView: contentView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Live Stream Tally"
            window.contentView = hostingView
            window.delegate = self
            window.aspectRatio = NSSize(width: 16, height: 9)
            window.makeKeyAndOrderFront(nil)

            Logger.info("Manually created window for Login Item launch", category: .app)

            // Activate the app
            NSApplication.shared.activate(ignoringOtherApps: true)

            // Mark window setup as completed since we created it manually
            windowSetupCompleted = true

            // Start NDI immediately since window is ready
            startNDIIfReady()
        }
    }

    /// Called by LiveStreamTallyApp when ContentView.onAppear fires
    /// This signals that the window is fully created and ready for configuration
    /// Note: This may not be called during Login Item launch if we manually created the window
    func windowDidAppear() {
        guard !windowSetupCompleted else {
            Logger.debug("Window setup already completed (manual creation), skipping", category: .app)
            return
        }

        Logger.info("ContentView appeared, completing window setup - isActive: \(NSApp.isActive), windows: \(NSApp.windows.count)", category: .app)

        // Ensure we're a regular app (in case it wasn't set earlier)
        NSApp.setActivationPolicy(.regular)

        configureWindow()
        windowSetupCompleted = true

        // Now that window is ready and view models are available, start NDI
        startNDIIfReady()
    }

    private func configureWindow() {
        // Find the window created by WindowGroup
        guard let window = NSApp.windows.first else {
            Logger.error("No window found when attempting configuration", category: .app)
            return
        }

        Logger.debug("Configuring window... isVisible: \(window.isVisible), isKeyWindow: \(window.isKeyWindow), isOnActiveSpace: \(window.isOnActiveSpace)", category: .app)

        // Set ourselves as the window delegate
        window.delegate = self

        // Configure window properties
        window.title = "Live Stream Tally"
        window.aspectRatio = NSSize(width: 16, height: 9)

        // Ensure window level allows it to be visible
        // NSWindow.Level.normal is standard, but we ensure it's not .statusBar or hidden
        window.level = .normal

        // CRITICAL: Multiple activation steps for Login Item launches
        // Each of these is necessary for reliable window appearance

        // Step 1: Make key and order front
        window.makeKeyAndOrderFront(nil)

        // Step 2: Center the window on screen
        window.center()

        // Step 3: Force window to front regardless of other app states
        // This is the most aggressive window ordering method
        window.orderFrontRegardless()

        // Step 4: Activate the app (this must come after window ordering)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Step 5: Ensure the window is actually visible and not minimized
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        // Step 6: Make window key again (in case activation changed focus)
        window.makeKey()

        Logger.info("Window configured and activated - isActive: \(NSApp.isActive), isVisible: \(window.isVisible), isKeyWindow: \(window.isKeyWindow)", category: .app)
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
