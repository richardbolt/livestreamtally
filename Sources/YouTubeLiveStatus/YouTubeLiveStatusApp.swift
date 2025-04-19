import SwiftUI

@main
struct YouTubeLiveStatusApp: App {
    @StateObject private var ndiViewModel = NDIViewModel()
    @StateObject private var mainViewModel = MainViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ndiViewModel)
                .environmentObject(mainViewModel)
        }
        .windowStyle(.hiddenTitleBar)
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
            
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(ndiViewModel)
                .environmentObject(mainViewModel)
        }
    }
}

