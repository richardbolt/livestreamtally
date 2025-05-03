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
    
    // Add app delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        Logger.debug("LiveStreamTallyApp init", category: .app)
        // Use the shared instance instead of creating a new one each time
        let sharedVM = LiveStreamTallyApp.sharedMainViewModel
        _mainViewModel = StateObject(wrappedValue: sharedVM)
        // Initialize NDIViewModel without the mainViewModel reference initially
        let initialNDIViewModel = NDIViewModel() // Create instance first
        _ndiViewModel = StateObject(wrappedValue: initialNDIViewModel) // Wrap it

        // Pass view model instances to AppDelegate
        appDelegate.mainViewModel = sharedVM
        appDelegate.ndiViewModel = initialNDIViewModel

        // Now setup lifecycle handler with the initialized NDIViewModel
        lifecycleHandler.setupWithNDIViewModel(initialNDIViewModel)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 640, minHeight: 360)
                .frame(maxWidth: 1920, maxHeight: 1080)
                .environmentObject(mainViewModel)
                .environmentObject(ndiViewModel)
                .onAppear {
                    Task { @MainActor in
                        Logger.debug("ContentView onAppear", category: .app)
                        // Set up the NDI view model with mainViewModel only after window exists
                        ndiViewModel.setupWithMainViewModel(mainViewModel)
                        // Set up the NDI view model in our lifecycle handler
                        lifecycleHandler.setupWithNDIViewModel(ndiViewModel)
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

// Add MainWindowController class
@MainActor
class MainWindowController: NSWindowController {
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        Logger.debug("MainWindowController windowDidLoad", category: .app)
    }
}

// Add AppDelegate class
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    // Add properties to hold view model instances
    var mainViewModel: MainViewModel?
    var ndiViewModel: NDIViewModel?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Logger.debug("applicationWillFinishLaunching", category: .app)
        // Attempt early activation
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.debug("applicationDidFinishLaunching", category: .app)

        guard let mainViewModel = mainViewModel, let ndiViewModel = ndiViewModel else {
            Logger.error("View models not available in AppDelegate", category: .app)
            return
        }

        // --- Manual Window Creation & Configuration ---
        Logger.debug("Manually creating and showing main window", category: .app)

        let contentView = ContentView()
            .environmentObject(mainViewModel)
            .environmentObject(ndiViewModel)
        
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720), // Initial size
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.center() // Center on screen
        window.setFrameAutosaveName("Main Window") // Remember position
        window.isReleasedWhenClosed = false
        window.title = "Live Stream Tally"
        window.contentView = hostingView
        window.aspectRatio = NSSize(width: 16, height: 9)
        window.collectionBehavior = [.managed]
        window.delegate = self // Handle close

        // Create and retain window controller
        windowController = MainWindowController(window: window)
        
        // Show the window and make it key
        windowController?.showWindow(nil) // Use the controller to show
        window.makeKeyAndOrderFront(nil) 
        
        // Activate the application
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // --- Start NDI --- 
        // Moved from ContentView.onAppear
        Logger.debug("Starting NDI stream from AppDelegate after window setup", category: .app)
        ndiViewModel.setupWithMainViewModel(mainViewModel)
        ndiViewModel.startStreaming()
        // -----------------

        // Removed delayed activation task as we now create/show directly
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Logger.debug("applicationShouldHandleReopen: \(flag)", category: .app)
        if !flag {
            // If the window was closed, find it and bring it to the front
            for window in sender.windows {
                if window.title == "Live Stream Tally" {
                    window.makeKeyAndOrderFront(self)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    break
                }
            }
        } else {
            // If windows are just hidden, standard activation is enough
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("Application will terminate, cleaning up resources", category: .app)
        // Clean up NDI resources
        // Accessing NDIViewModel here might be tricky due to lifecycle.
        // Consider adding a static cleanup method or ensuring NDIViewModel handles its own cleanup in deinit.
        // For now, we rely on the lifecycleHandler or NDIViewModel's deinit
        
        // Ensure clean shutdown of services if needed
    }
}

// Conform AppDelegate to NSWindowDelegate to handle window closing
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Logger.debug("Main window closing", category: .app)
        // Stop NDI streaming when the main window is closed
        ndiViewModel?.stopStreaming()
        // Allow the app to terminate if needed (or keep running if menu bar extra exists)
        // Check standard behavior or implement custom logic if required
    }
    
    // Optional: Decide if app should terminate when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Logger.debug("applicationShouldTerminateAfterLastWindowClosed called", category: .app)
        return true // Standard behavior, change if using MenuBarExtra primarily
    }
}

