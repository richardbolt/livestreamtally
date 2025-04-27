#!/bin/bash
#
# run_tests.sh
# LiveStreamTally Test Runner
#
# Updated to use Swift Testing exclusively
#

# Set bash to exit immediately if any command fails
set -e

echo "LiveStreamTally Test Runner"
echo "---------------------------"

# Check if target is provided
if [ "$1" == "" ]; then
    echo "Usage: ./run_tests.sh [test_target]"
    echo
    echo "Available test targets:"
    echo "  all                      - Run all Swift Testing tests"
    echo "  YouTubeService           - Tests for YouTube API integration"
    echo "  PreferencesManager       - Tests for preferences management"
    echo "  MainViewModel            - Tests for the main view model"
    echo "  UI                       - Tests for UI components"
    echo "  NDIBroadcaster           - Tests for NDI broadcasting"
    echo "  ParameterizedTests       - Examples of parameterized tests"
    echo
    echo "Examples:"
    echo "  ./run_tests.sh YouTubeService"
    echo "  ./run_tests.sh MainViewModel"
    echo
    exit 1
fi

TEST_TARGET=$1

echo "Running Swift Testing framework tests for target: $TEST_TARGET"
echo

# Run Swift Testing tests with specified target
if [ "$TEST_TARGET" == "all" ]; then
    echo "Running all Swift Testing tests..."
    swift test --enable-swift-testing
else
    # Convert target to the suite name pattern used in the code
    case "$TEST_TARGET" in
        "YouTubeService")
            SUITE_NAME="YouTubeServiceTests"
            ;;
        "PreferencesManager")
            SUITE_NAME="PreferencesManagerTestsSuite"
            ;;
        "MainViewModel")
            SUITE_NAME="MainViewModelTestingSuite"
            ;;
        "UI")
            SUITE_NAME="UITestsSuite"
            ;;
        "NDIBroadcaster")
            SUITE_NAME="NDIBroadcasterTestsSuite"
            ;;
        "ParameterizedTests")
            SUITE_NAME="ParameterizedTests"
            ;;
        *)
            echo "Unknown test target: $TEST_TARGET"
            exit 1
            ;;
    esac
    
    echo "Running Swift Testing tests for suite: '$SUITE_NAME'..."
    swift test --enable-swift-testing --filter "$SUITE_NAME"
fi

echo
echo "Test run complete." 