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
```

Available test targets: `YouTubeService`, `PreferencesManager`, `MainViewModel`, `UI`, `NDIBroadcaster`, `ParameterizedTests`

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
- Renders SwiftUI ContentView to video frames at 720p (1280x720, 30fps, 16:9 aspect)
- Sends metadata frames with live status, viewer count, and title

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
- Many tests are `.disabled()` because they require real API keys or NDI hardware
- Mock implementations available in `Tests/LiveStreamTallyTests/Mocks.swift`
- All test methods interacting with `@MainActor` classes must be `async`

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
- Video frames: BGRA format, progressive scan
- Metadata: XML-like string format embedded in `NDIlib_metadata_frame_t`

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
