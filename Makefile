# Makefile
# LiveStreamTally
#
# Created by Richard Bolt
# Copyright © 2025 Richard Bolt. All rights reserved.
#
# This file is part of LiveStreamTally, released under the MIT License.
# See the LICENSE file for details.

# Configuration
APP_NAME = LiveStreamTally
SWIFT = swift
SWIFT_BUILD_FLAGS = -c release
SIGN_IDENTITY ?= "-"  # Use "-" for ad-hoc signing, or set via environment variable

.PHONY: all clean build run sign package test help

# Default target
all: clean build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .build
	rm -rf $(APP_NAME).app

# Build the Swift package
build-swift:
	@echo "Building Swift package..."
	$(SWIFT) build $(SWIFT_BUILD_FLAGS)

# Create the app bundle using the build_app.sh script
build: build-swift
	@echo "Creating app bundle..."
	./build_app.sh

# Run the app
run:
	@echo "Running $(APP_NAME)..."
	open $(APP_NAME).app

# Just sign the app (useful if you only changed the signing identity)
sign:
	@echo "Signing app with identity: $(SIGN_IDENTITY)..."
	codesign --force --deep --options runtime --sign "$(SIGN_IDENTITY)" --entitlements $(APP_NAME).entitlements --identifier com.livestreamtally.app $(APP_NAME).app
	codesign -vv -d $(APP_NAME).app

# Create a distributable package
package: build
	@echo "Creating distributable package..."
	mkdir -p dist
	ditto -c -k --keepParent $(APP_NAME).app dist/$(APP_NAME).zip
	@echo "Package created at dist/$(APP_NAME).zip"

# Run tests
test:
	@echo "Running tests..."
	@echo "Note: Tests require NDI SDK to be installed at /Library/NDI SDK for Apple/"
	@echo "To run specific tests without NDI, use: ./run_tests.sh [test_target]"
	./run_tests.sh all

# Open a log stream
logs:
	@echo "Opening a log stream"
	log stream --predicate 'subsystem == "com.livestreamtally.app"' --level debug

# Display help information
help:
	@echo "LiveStreamTally Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all        Clean and build the app (default)"
	@echo "  clean      Remove build artifacts"
	@echo "  build      Build the app and create app bundle"
	@echo "  run        Run the app"
	@echo "  sign       Sign the app (use SIGN_IDENTITY env var to specify identity)"
	@echo "  package    Create a distributable zip package"
	@echo "  test       Run Swift tests"
	@echo "  logs       Stream debug+ level logs from the app"
	@echo "  help       Display this help information"
	@echo ""
	@echo "Examples:"
	@echo "  make                       # Clean and build the app"
	@echo "  make run                   # Build and run the app"
	@echo "  SIGN_IDENTITY=\"Developer ID\" make sign  # Sign with specific identity" 