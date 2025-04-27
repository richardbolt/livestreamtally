# LiveStreamTally Testing

This directory contains test scaffolding for the LiveStreamTally application. The tests use Swift 6.1's Swift Testing framework and are designed to work with strict actor isolation.

## Swift Testing Framework

LiveStreamTally uses Swift Testing, a modern testing framework introduced with Swift 6.1 that offers a more Swift-native approach compared to the older XCTest framework. It works seamlessly with Swift's concurrency model, offering improved syntax, better error messages, and parallel test execution by default.

### Benefits of Swift Testing

- **Modern, Swift-native syntax** with macros like `@Test`, `#expect`, and `#require`
- **Parameterized testing** allows running the same test with different inputs
- **Parallel execution** by default
- **First-class support for async/await** and Swift concurrency
- **Better error messages** with detailed context
- **Tagging system** for organizing tests by feature or functionality
- **Descriptive test names** for better readability

## Test Structure

The test suite is organized into the following test files:

- **YouTubeServiceTests.swift**: Tests for the YouTube API integration
- **PreferencesManagerTests.swift**: Tests for user preference storage and retrieval
- **MainViewModelTests.swift**: Tests for the main view model functionality
- **NDIBroadcasterTests.swift**: Tests for NDI broadcasting capabilities
- **UITests.swift**: Tests for SwiftUI components
- **ParameterizedTestingExamples.swift**: Examples of parameterized testing capabilities
- **Mocks.swift**: Mock implementations of services for testing

## Actor Isolation and Concurrency

Since LiveStreamTally uses Swift 6.1's strict actor isolation with `@MainActor` on many of its classes, all tests that interact with these classes need to respect actor isolation. This means:

1. Test methods that interact with `@MainActor`-isolated classes must be marked as `async`
2. Calls to actor-isolated methods must use `await`
3. Assertions against actor-isolated properties must be performed within an actor context

Example of a properly isolated test:

```swift
@Test func testApiKeyChangeHandling() async throws {
    // Initialize a @MainActor-isolated class
    let viewModel = try await MainViewModel()
    
    // Call an actor-isolated method using await
    await viewModel.handleApiKeyChanged()
    
    // Make assertions
    #expect(viewModel.error == nil)
}
```

## Running Tests

To run all tests:

```bash
./run_tests.sh all
```

To run a specific test suite:

```bash
./run_tests.sh YouTubeService  # Replace with any test target from the script
```

Available test targets:
- `YouTubeService`
- `PreferencesManager`
- `MainViewModel`
- `UI`
- `NDIBroadcaster`
- `ParameterizedTests`

## Writing Tests with Swift Testing

### Basic Test

A basic test in Swift Testing looks like this:

```swift
import Testing
@testable import LiveStreamTally

@Test func testYouTubeService() async throws {
    let service = try await YouTubeService(apiKey: "test_api_key")
    #expect(!service.apiKey.isEmpty)
}
```

### Test Suite

Group related tests in a suite:

```swift
@Suite("YouTube Service Tests")
struct YouTubeServiceTests {
    private let testApiKey = "test_api_key"
    
    @Test func testInitWithEmptyApiKey() async throws {
        await #expect(throws: YouTubeError.invalidApiKey) {
            try await YouTubeService(apiKey: "")
        }
    }
    
    @Test func testInitWithValidApiKey() async throws {
        let service = try await YouTubeService(apiKey: testApiKey)
        #expect(true)
    }
}
```

### Parameterized Tests

Test multiple inputs with the same test function:

```swift
@Test("Should validate different channel ID formats",
      arguments: [
        "UC1234567890",          // Standard channel ID
        "@Username",             // Handle with @ prefix
        "Username",              // Handle without @ prefix
        "channel/UC1234567890",  // Full channel path
      ])
func channelIdValidation(channelId: String) {
    let isValid = !channelId.isEmpty
    #expect(isValid, "Channel ID should not be empty")
}
```

### Disabled Tests

Some tests are disabled to prevent them from running automatically:

1. Tests that require external resources (e.g., a YouTube API key)
2. Tests that depend on NDI hardware/runtime
3. Integration tests that might exceed API quotas

To disable a test, use the `.disabled` trait:

```swift
@Test(.disabled("Requires real API key"))
func testResolveChannelIdentifier() async throws {
    // Test code that uses real API keys...
}
```

## Common Assertions

Swift Testing uses `#expect` and `#require` instead of various XCTest assertions:

- Basic assertion: `#expect(expression)`
- With custom message: `#expect(expression, "Error message")`
- Testing for errors: `await #expect(throws: ErrorType) { /* code */ }`
- Unwrapping optionals: `let value = try #require(optionalValue)`

## Adding New Tests

When adding new tests:

1. Create test methods that match the actor isolation of the components being tested
2. Use mocks from the `Mocks.swift` file for testing components in isolation
3. Organize related tests in a `@Suite`
4. Properly handle async/await for actor-isolated code
5. Consider using parameterized tests for testing multiple inputs

## References

- [Swift Testing Documentation](https://developer.apple.com/xcode/swift-testing/)
- [WWDC24: Unveiling Swift Testing](https://developer.apple.com/videos/play/wwdc24/1234) 
- [Swift Forums: Swift Testing Discussions](https://forums.swift.org/c/swift-testing) 