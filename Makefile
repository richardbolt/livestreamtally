# Makefile
# LiveStreamTally
#
# Created by Richard Bolt
# Copyright © 2025 Richard Bolt. All rights reserved.
#
# This file is part of LiveStreamTally, released under the MIT License.
# See the LICENSE file for details.

# Configuration
APP_NAME = Live Stream Tally
APP_BUNDLE_ID = com.richardbolt.livestreamtally
SWIFT = swift
SWIFT_BUILD_FLAGS = -c release
SIGN_IDENTITY ?= "-"  # Use "-" for ad-hoc signing, or set via environment variable SIGN_IDENTITY
NOTARY_PROFILE ?= "YourProfileNameForNotary" # Set via environment variable NOTARY_PROFILE (created with xcrun notarytool store-credentials)
ARCHIVE_NAME = $(APP_NAME)-signed.zip

.PHONY: all clean build run sign notarize staple package package-dmg package-zip test help

# Default target
all: clean build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .build
	rm -rf "$(APP_NAME).app"

# Build the Swift package
build-swift:
	@echo "Building Swift package..."
	$(SWIFT) build $(SWIFT_BUILD_FLAGS)

# Create the app bundle using the build_app.sh script
build: build-swift
	@echo "Creating app bundle..."
	export APP_NAME="$(APP_NAME)"; \
	./build_app.sh

# Run the app
run:
	@echo "Running $(APP_NAME)..."
	open "$(APP_NAME).app"

# Just sign the app (useful if you only changed the signing identity)
sign: build
	@echo "Signing app '$(APP_NAME).app' with identity: $(SIGN_IDENTITY)..."
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "Warning: Signing with ad-hoc identity. Use SIGN_IDENTITY=\"Your Developer ID\" for distribution signing."; \
		codesign --force --deep --options runtime --sign "$(SIGN_IDENTITY)" "$(APP_NAME).app"; \
	else \
		codesign --force --deep --options runtime --sign "$(SIGN_IDENTITY)" --entitlements LiveStreamTally.entitlements --identifier "$(APP_BUNDLE_ID)" "$(APP_NAME).app"; \
		codesign -vv -d "$(APP_NAME).app"; \
	fi

# Notarize the signed app
notarize: sign
	@echo "Archiving app for notarization..."
	ditto -c -k --keepParent "$(APP_NAME).app" "$(ARCHIVE_NAME)"
	@echo "Submitting $(ARCHIVE_NAME) for notarization using profile: $(NOTARY_PROFILE)..."
	@echo "This may take several minutes. Waiting for results..."
	xcrun notarytool submit "$(ARCHIVE_NAME)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	@echo "Notarization submission complete. Cleaning up archive..."
	rm "$(ARCHIVE_NAME)"

# Staple the notarization ticket to the app
staple: notarize
	@echo "Stapling notarization ticket to '$(APP_NAME).app'..."
	xcrun stapler staple "$(APP_NAME).app"
	@echo "Stapling complete."
	@echo "Verifying stapling..."
	xcrun stapler validate "$(APP_NAME).app"
	spctl --assess -vv "$(APP_NAME).app"

# Create a distributable package (Notarized DMG)
package: staple
	@echo "Creating distributable package..."
	mkdir -p dist
	@echo "Creating DMG..."
	./create_dmg.sh
	@echo "Package created at dist/$(APP_NAME).dmg"

# Create a DMG package (Notarized)
package-dmg: staple
	@echo "Creating DMG package..."
	mkdir -p dist
	./create_dmg.sh
	@echo "DMG created at dist/$(APP_NAME).dmg"

# Create a distributable ZIP package (legacy, signed but not notarized/stapled)
package-zip: sign
	@echo "Creating legacy signed ZIP package (not notarized)..."
	mkdir -p dist
	ditto -c -k --keepParent "$(APP_NAME).app" "dist/$(APP_NAME).zip"
	@echo "ZIP package created at dist/$(APP_NAME).zip"

# Run tests
test:
	@echo "Running tests..."
	@echo "Note: Tests require NDI SDK to be installed at /Library/NDI SDK for Apple/"
	@echo "To run specific tests without NDI, use: ./run_tests.sh [test_target]"
	./run_tests.sh all

# Open a log stream
logs:
	@echo "Opening a log stream"
	log stream --predicate 'subsystem == "com.richardbolt.livestreamtally"' --level debug

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
	@echo "  sign       Sign the app (use SIGN_IDENTITY env var to specify Developer ID)"
	@echo "  notarize   Sign and submit the app to Apple for notarization (requires SIGN_IDENTITY and NOTARY_PROFILE env vars)"
	@echo "  staple     Sign, notarize, and staple the ticket to the app (requires SIGN_IDENTITY and NOTARY_PROFILE env vars)"
	@echo "  package    Create a distributable notarized DMG package (depends on staple)"
	@echo "  package-dmg Create a distributable notarized DMG package (same as package)"
	@echo "  package-zip Create a distributable signed ZIP package (legacy, not notarized)"
	@echo "  test       Run Swift tests"
	@echo "  logs       Stream debug+ level logs from the app"
	@echo "  help       Display this help information"
	@echo ""
	@echo "Environment Variables:"
	@echo "  SIGN_IDENTITY   Set to your 'Developer ID Application: Your Name (ID)' for signing."
	@echo "  NOTARY_PROFILE  Set to the profile name created with 'xcrun notarytool store-credentials' for notarization."
	@echo ""
	@echo "Examples:"
	@echo "  make                       # Clean and build the app (ad-hoc signed)"
	@echo "  make run                   # Build and run the app (ad-hoc signed)"
	@echo "  SIGN_IDENTITY=\"Developer ID Application: Your Name (XXXXXXXXXX)\" make sign"
	@echo "  SIGN_IDENTITY=\"...\" NOTARY_PROFILE=\"YourProfile\" make staple # Sign, notarize, staple"
	@echo "  SIGN_IDENTITY=\"...\" NOTARY_PROFILE=\"YourProfile\" make package # Build final DMG" 