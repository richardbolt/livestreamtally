# LiveStreamTally Test Plan

This document outlines the test strategy and key areas to test in the LiveStreamTally application.

## Application Overview

LiveStreamTally is a macOS application that monitors a YouTube channel's live streaming status and broadcasts this information via NDI. The application has several key components:

1. **YouTube Integration**: Fetches live stream status from YouTube's Data API
2. **Preferences Management**: Handles user settings (API key, channel ID, etc.)
3. **NDI Broadcasting**: Sends status information via NDI
4. **UI Components**: SwiftUI interface for displaying status and settings

## Key Areas to Test

### 1. YouTube Service Testing

- **API Integration**: Test that the application correctly communicates with YouTube Data API
- **Channel Resolution**: Verify that channel IDs and handles are correctly resolved
- **Live Status Detection**: Ensure the app accurately detects live/offline status
- **Error Handling**: Test various error conditions (invalid API key, quota exceeded, etc.)

### 2. Preferences Management Testing

- **Storage**: Test that preferences are correctly saved and retrieved
- **Persistence**: Verify that preferences survive application restarts
- **Security**: Validate that API keys are stored securely in the keychain
- **Notifications**: Test that preference changes trigger appropriate notifications

### 3. NDI Broadcasting Testing

- **Metadata**: Test that NDI metadata is correctly formatted
- **Image Generation**: Verify that the NDI image is generated with correct size and content
- **Frame Rate**: Ensure NDI frames are sent at appropriate intervals
- **Start/Stop**: Test that broadcasting can be started and stopped correctly

### 4. View Model Testing

- **State Management**: Test that the view model correctly manages application state
- **Data Propagation**: Verify that YouTube status updates flow to the UI
- **Timer Management**: Test that polling intervals are correctly adjusted based on live status
- **Error Handling**: Verify that errors are properly communicated to the UI

### 5. UI Testing

- **Layout**: Test that UI components adapt to different window sizes
- **Dark Mode**: Verify that the application supports light and dark mode
- **Responsiveness**: Ensure the UI remains responsive during data fetching
- **Accessibility**: Test keyboard navigation and VoiceOver support

## Test Types

### Unit Tests

Unit tests should focus on individual components, using mock implementations for dependencies. Key areas include:

- YouTube service parsing and error handling
- Preference storage and retrieval
- NDI metadata formatting
- View model state management

### Integration Tests

Integration tests should verify how components work together:

- YouTube service to view model data flow
- Preference changes affecting the YouTube service
- View model updates reflecting in UI components

### UI Tests

UI tests should validate the user interface:

- Navigation between views
- Form input validation
- Status display updates
- Settings configuration

### Performance Tests

Performance tests should measure:

- YouTube API polling efficiency
- NDI frame generation speed
- UI responsiveness during background operations

## Testing Challenges

### NDI Dependencies

NDI functionality requires the NDI SDK to be installed, which complicates automated testing. Strategies include:

1. Mocking the NDI interface for unit tests
2. Using a test-specific implementation for integration tests
3. Running full NDI tests only on systems with NDI SDK installed

### Actor Isolation

Swift 6.1's strict actor isolation requires careful test design:

1. Test methods that interact with `@MainActor` code must be marked as `@MainActor`
2. Asynchronous testing using `async/await` is required
3. Tests must respect actor boundaries to avoid data races

### API Keys and Quotas

YouTube API testing requires valid API keys and is subject to quota limitations:

1. Use mock responses for most tests
2. Limit actual API calls to essential integration tests
3. Consider using dedicated test API keys with separate quotas

## Recommended Testing Tools

1. **XCTest**: Core testing framework for Swift
2. **ViewInspector**: For testing SwiftUI views
3. **Snapshot Testing**: For validating UI appearance
4. **Network Mocking**: OHHTTPStubs or similar for mocking API responses

## Test Environment Setup

1. Development machines with macOS 13.0+
2. Test instances with and without NDI SDK installed
3. Multiple test API keys to avoid quota issues
4. Representative test data for various YouTube channel states 