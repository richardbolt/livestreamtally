# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Live Stream Tally is a native macOS application (Swift 6.1/SwiftUI) that monitors a YouTube channel's live streaming status and outputs it via NDI (Network Device Interface) for integration with professional broadcasting equipment. The app provides real-time ON AIR/OFF AIR status, viewer counts, and stream titles as both a visual display and NDI tally signals.

## Build & Development Commands

### Basic Development Workflow
```bash
make                    # Clean and build (creates ad-hoc signed app)
make run                # Build and launch the app
OS_ACTIVITY_MODE=debug make run  # Run with debug logging enabled
make logs               # Stream app logs in real-time
```

### Testing
```bash
make test                           # Run all tests (requires NDI SDK)
./run_tests.sh YouTubeServiceTests  # Run specific test suite
swift test --filter TestName        # Run single test method

# Run YouTube API integration tests with real credentials
YOUTUBE_API_KEY=your_api_key \
YOUTUBE_TEST_CHANNEL_ID=UCxxxxxxxxxx \
swift test --filter YouTubeServiceTests.integration
```

Available test targets: `YouTubeService`, `PreferencesManager`, `MainViewModel`, `UI`, `NDIBroadcaster`, `ParameterizedTests`

**Note**: YouTube API integration tests are conditionally enabled only when both `YOUTUBE_API_KEY` and `YOUTUBE_TEST_CHANNEL_ID` environment variables are set. Without these, the tests will be gracefully skipped.

### Distribution Builds
```bash
# Requires Apple Developer ID certificate and notarytool profile configured
SIGN_IDENTITY="Developer ID Application: Your Name (XXXXXXXXXX)" \
NOTARY_PROFILE="YourProfileNameForNotary" \
make package           # Creates signed, notarized DMG in dist/
```

## Architecture & Key Patterns

### Actor Isolation (Swift 6.1)
**CRITICAL**: This codebase uses Swift 6.1's strict concurrency model. Most classes are marked `@MainActor`:
- `MainViewModel`, `YouTubeService`, `PreferencesManager` are all `@MainActor`
- All functions that interact with these classes must use `await`
- Test methods must be marked `async` when testing actor-isolated code
- When adding new code, respect actor isolation boundaries

### State Management Pattern
The app uses a centralized state management approach:

1. **PreferencesManager** (singleton, `@MainActor`):
   - Central source of truth for all user preferences
   - Uses `@Published` properties for reactive updates
   - Wraps `UserDefaults` for persistence
   - Posts notifications via `NotificationCenter` for cross-component communication
   - Key notification names: `apiKeyChanged`, `channelChanged`, `intervalChanged`

2. **KeychainManager** (singleton, `@MainActor`):
   - Securely stores YouTube API key in macOS Keychain
   - Called through PreferencesManager, never directly from ViewModels

3. **MainViewModel** (shared instance):
   - Observes PreferencesManager notifications to react to configuration changes
   - Uses Combine subscriptions to sync with PreferencesManager published properties
   - Creates `YouTubeService` instance per ViewModel (service creation is fast: ~0.03ms)
   - Implements dynamic polling intervals (faster when live, slower when offline)
   - Consolidates all app state with `@Published` properties directly in the ViewModel

### NDI Integration
- **NDIBroadcaster**: C/Swift interop with NDI SDK via `NDIWrapper` system library
- **NDIViewModel**: Coordinates between MainViewModel and NDIBroadcaster
- Renders SwiftUI ContentView to video frames at 720p (1280x720, 1fps, 16:9 aspect)
- Sends metadata frames with live status, viewer count, and title
- Frame rate optimized to 1Hz to match content update frequency (time display updates every second)

### YouTube API Integration
- **YouTubeService** (`@MainActor`):
  - Wraps Google API Client for REST (YouTube Data API v3)
  - Implements caching: stores `currentLiveVideoId` to minimize API calls
  - Handles channel identifier resolution (supports channel IDs, @handles, or plain handles)
  - Two-step live check: 1) Check cached video ID first, 2) Fall back to playlist query
  - Call `clearCache()` when channel changes to force fresh lookup

### View Architecture
- **ContentView**: Main SwiftUI view with ON AIR/OFF AIR display
- **SettingsView**: Configuration interface for API key, channel ID, polling intervals
- **ViewModels**: `MainViewModel`, `SettingsViewModel`, `NDIViewModel` follow MVVM pattern
- All ViewModels are injected via `.environmentObject()` in `LiveStreamTallyApp.swift`

### Lifecycle Management
- **AppDelegate**: Handles window management and NDI startup
- **AppLifecycleHandler**: Ensures clean NDI shutdown on app termination
- Window closes = app terminates (no persistent menu bar mode)

#### CRITICAL: Login Item Window Creation
**DO NOT MODIFY OR REMOVE THIS FUNCTIONALITY** - The app must properly display its window when launched as a macOS Login Item.

When the app is launched as a Login Item (at user login), SwiftUI's `WindowGroup` does NOT automatically create a window. This is a macOS behavior difference from normal app launches. The following critical implementation ensures the window appears correctly:

1. **Synchronous ViewModel Assignment** (`LiveStreamTallyApp.swift:36-38`):
   - View models MUST be assigned to `AppDelegate` synchronously during app initialization
   - The previous async approach created a race condition where `applicationDidFinishLaunching` could run before view models were available
   - This ensures view models are always available when AppDelegate needs them

2. **Manual Window Creation for Login Items** (`AppDelegate.swift:54-87`):
   - In `applicationDidFinishLaunching`, check if a window exists via `NSApp.windows.first`
   - If NO window exists (Login Item launch), manually create it using `NSHostingView` with the SwiftUI `ContentView`
   - Configure window properties: title, size (1280x720), 16:9 aspect ratio, and delegate
   - Use `makeKeyAndOrderFront` to display the window

3. **Multi-Step Window Activation** (`AppDelegate.swift:146-154`):
   - Set activation policy to `.regular` (not `.accessory` or `.prohibited`)
   - Call `makeKeyAndOrderFront(nil)` to make window visible
   - Call `center()` to position window on screen
   - Call `orderFrontRegardless()` - the most aggressive ordering method
   - Call `NSApplication.shared.activate(ignoringOtherApps: true)` to activate app
   - Check and deminiaturize if needed
   - Call `makeKey()` again to ensure window has focus
   - Each step is necessary for reliable window appearance across different macOS versions and states

4. **Window Setup Coordination** (`AppDelegate.swift:94-109`):
   - Track `windowSetupCompleted` flag to prevent duplicate setup
   - `windowDidAppear()` is called from `ContentView.onAppear` for normal launches
   - Skip `windowDidAppear()` if window was manually created (Login Item path)
   - Start NDI only after window setup is complete

5. **Startup Network Retry Logic** (`MainViewModel.swift:384-441`):
   - When monitoring starts at app launch, network may not be available yet
   - Automatically retry YouTube API calls with exponential backoff (1s, 2s, 4s, 8s, 16s)
   - Use `NWPathMonitor` to detect network availability
   - Provide user feedback during retries
   - Maximum 5 retry attempts before giving up
   - Cancel retry task when monitoring stops

**Testing Login Item Behavior**:
```bash
# Add app as Login Item in System Settings > General > Login Items
# Log out and log back in to test
# Window should appear immediately without user intervention
# Use OS_ACTIVITY_MODE=debug to see detailed logs during login
```

**Symptoms of Broken Login Item Support**:
- App launches at login but no window appears
- User must click dock icon or use Cmd+Tab to make window appear
- Window exists but is hidden/behind other windows
- Race conditions where view models are nil in AppDelegate

## Important Implementation Details

### When API Key or Channel Changes
1. PreferencesManager updates UserDefaults/Keychain
2. PreferencesManager posts notification
3. MainViewModel observes notification
4. MainViewModel recreates YouTubeService (for API key) or clears cache (for channel)
5. If monitoring is active, MainViewModel stops and restarts polling

### Polling Interval Logic
- Configured via PreferencesManager: `liveCheckInterval` (default 5s) and `notLiveCheckInterval` (default 20s)
- Timer automatically switches intervals based on `isLive` state
- When interval preferences change, active timer is invalidated and recreated

### Testing Considerations
- Uses Swift Testing framework (not XCTest)
- Assertions use `#expect()` and `#require()` syntax
- Integration tests use `.enabled(if:)` trait to conditionally run when required resources are available
- Mock implementations available in `Tests/LiveStreamTallyTests/Mocks.swift`
- All test methods interacting with `@MainActor` classes must be `async`
- YouTube API integration tests require `YOUTUBE_API_KEY` and `YOUTUBE_TEST_CHANNEL_ID` environment variables
- NDI integration tests require NDI runtime at `/Library/NDI SDK for Apple/lib/macOS/libndi.dylib`

## Common Development Tasks

### Adding a New Preference
1. Add key constant to `PreferencesManager.Keys`
2. Add `@Published` property to PreferencesManager
3. Initialize in `PreferencesManager.init()` from UserDefaults
4. Add getter/setter methods
5. Update `setupObservations()` if external changes need to be observed
6. Create notification name if other components need to react
7. Subscribe to notification in relevant ViewModels

### Modifying YouTube API Calls
- All API calls go through `YouTubeService.executeQuery<T>()`
- Uses Google API Client types: `GTLRYouTubeQuery_*` for queries
- Returns are async via `CheckedContinuation`
- Handle quota exceeded errors specifically: check for `YouTubeError.quotaExceeded`

### Extending NDI Functionality
- NDI SDK installed at `/Library/NDI SDK for Apple/lib/macOS` (development requirement only)
- Swift wrapper module at `Sources/NDIWrapper/`
- All NDI calls must happen on main thread (use `@MainActor`)
- Video frames: BGRA format, progressive scan, 1fps (1Hz)
- Metadata: XML-like string format embedded in `NDIlib_metadata_frame_t`
- Frame rate: Optimized to 1Hz to match content update frequency and minimize CPU usage

## Dependencies

- **GoogleAPIClientForREST_YouTube** (3.0.0+): YouTube Data API v3 client
- **swift-log** (1.5.3+): Structured logging
- **NDI SDK**: Required for development/building; the built app packages the appropriately licensed NDI runtime

## File Structure
```
Sources/LiveStreamTally/
├── LiveStreamTallyApp.swift       # App entry point, lifecycle management
├── Models/
│   └── AppState.swift             # App state model
├── Services/
│   ├── YouTubeService.swift       # YouTube API integration
│   ├── NDIBroadcaster.swift       # NDI SDK wrapper
│   ├── PreferencesManager.swift   # Centralized preferences
│   └── KeychainManager.swift      # Secure API key storage
├── ViewModels/
│   ├── MainViewModel.swift        # Main UI state & YouTube polling
│   ├── SettingsViewModel.swift    # Settings UI state
│   └── NDIViewModel.swift         # NDI coordination
├── Views/
│   ├── ContentView.swift          # Main ON AIR/OFF AIR display
│   └── SettingsView.swift         # Settings interface
└── Utils/
    └── Logger.swift               # Logging utilities

Tests/LiveStreamTallyTests/
├── YouTubeServiceTests.swift
├── PreferencesManagerTests.swift
├── MainViewModelTests.swift
├── NDIBroadcasterTests.swift
├── UITests.swift
├── ParameterizedTestingExamples.swift
└── Mocks.swift
```

## Logging
- Custom Logger utility wraps swift-log
- Subsystem: `com.richardbolt.livestreamtally`
- Categories: `.app`, `.youtube`, `.main`, `.settings`
- View logs: `make logs` or `log stream --predicate 'subsystem == "com.richardbolt.livestreamtally"' --level debug`

## Known Considerations

- **API Quota**: YouTube Data API v3 has daily quota limits. The app uses 2-3 quota units per live check.
- **NDI SDK Required for Development**: NDI SDK must be installed at `/Library/NDI SDK for Apple/` to build the app. The built and signed macOS app packages the appropriately licensed NDI runtime.
- **macOS 13.0+**: Minimum supported version due to SwiftUI requirements
- **Gatekeeper**: Ad-hoc signed builds (`make`) will run locally but may be blocked on other Macs; use `make package` for distribution
