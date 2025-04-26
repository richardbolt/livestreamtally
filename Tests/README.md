# LiveStreamTally Tests

This directory contains test scaffolding for the LiveStreamTally application. The tests are designed to work with Swift 6.1's strict actor isolation.

## Test Structure

The test suite is organized into the following test files:

- **YouTubeServiceTests.swift**: Tests for the YouTube API integration
- **PreferencesManagerTests.swift**: Tests for user preference storage and retrieval
- **MainViewModelTests.swift**: Tests for the main view model functionality
- **NDIBroadcasterTests.swift**: Tests for NDI broadcasting capabilities
- **UITests.swift**: Tests for SwiftUI components
- **Mocks.swift**: Mock implementations of services for testing

## Actor Isolation and Concurrency

Since LiveStreamTally uses Swift 6.1's strict actor isolation with `@MainActor` on many of its classes, all tests that interact with these classes need to respect actor isolation. This means:

1. Test methods that interact with `@MainActor`-isolated classes must be marked as `async`
2. Calls to actor-isolated methods must use `await`
3. Assertions against actor-isolated properties must be performed within an actor context

Example of a properly isolated test:

```swift
@MainActor // Mark the test as running on the main actor
func testExample() async throws {
    // Initialize a @MainActor-isolated class
    let viewModel = await MainViewModel()
    
    // Call an actor-isolated method using await
    await viewModel.someMethod()
    
    // Now we can access properties directly since we're in the same actor
    XCTAssertEqual(viewModel.someProperty, expectedValue)
}
```

## Running Tests

To run the full test suite:

```bash
make test
```

To run a specific test class:

```bash
swift test --filter ClassNameTests
```

To run a specific test method:

```bash
swift test --filter ClassNameTests/testMethodName
```

## Adding New Tests

When adding new tests:

1. Create test methods that match the actor isolation of the components being tested
2. Use mocks from the `Mocks.swift` file for testing components in isolation
3. For UI testing, consider using ViewInspector or snapshot testing libraries
4. Properly handle async/await for actor-isolated code

## Disabled Tests

Some tests are prefixed with `disabled` to prevent them from running automatically:

1. Tests that require external resources (e.g., a YouTube API key)
2. Tests that depend on NDI hardware/runtime
3. Integration tests that might exceed API quotas

To run a disabled test, rename it from `disabledTestExample()` to `testExample()`. 