#!/bin/bash
#
# build_app.sh
# LiveStreamTally
#
# Created by Richard Bolt
# Copyright © 2025 Richard Bolt. All rights reserved.
#
# This file is part of LiveStreamTally, released under the MIT License.
# See the LICENSE file for details.
#


# Exit on error
set -e

# Use APP_NAME from environment or default to "Live Stream Tally"
APP_NAME="${APP_NAME:-Live Stream Tally}"
APP_BUNDLE_NAME="${APP_NAME}.app"

# Optional: Set your Apple Developer ID here
SIGN_IDENTITY="${SIGN_IDENTITY:-"-"}" # Use "-" for ad-hoc

echo "Building $APP_NAME app..."

# Clean up any existing app bundle
rm -rf "$APP_BUNDLE_NAME"

# Create app bundle structure
mkdir -p "$APP_BUNDLE_NAME/Contents/MacOS"
mkdir -p "$APP_BUNDLE_NAME/Contents/Resources"
mkdir -p "$APP_BUNDLE_NAME/Contents/Frameworks"

# Create iconset directory
ICONSET="$APP_BUNDLE_NAME/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET"

# Copy and rename icons
echo "Creating iconset..."
echo "Copying icons from Sources/LiveStreamTally/Resources/AppIcon.appiconset/"
ls -la Sources/LiveStreamTally/Resources/AppIcon.appiconset/
echo "To $ICONSET"
ls -la "$ICONSET" || echo "Iconset directory is empty"

cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_16x16.png "$ICONSET/icon_16x16.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_16x16@2x.png "$ICONSET/icon_16x16@2x.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_32x32.png "$ICONSET/icon_32x32.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_32x32@2x.png "$ICONSET/icon_32x32@2x.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_128x128.png "$ICONSET/icon_128x128.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_128x128@2x.png "$ICONSET/icon_128x128@2x.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_256x256.png "$ICONSET/icon_256x256.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_256x256@2x.png "$ICONSET/icon_256x256@2x.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_512x512.png "$ICONSET/icon_512x512.png"
cp Sources/LiveStreamTally/Resources/AppIcon.appiconset/icon_512x512@2x.png "$ICONSET/icon_512x512@2x.png"

echo "Iconset contents after copying:"
ls -la "$ICONSET"

# Convert iconset to icns
echo "Converting iconset to icns..."
iconutil -c icns -o "$APP_BUNDLE_NAME/Contents/Resources/AppIcon.icns" "$ICONSET"

# Copy executable
cp .build/release/LiveStreamTally "$APP_BUNDLE_NAME/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_BUNDLE_NAME/Contents/"

# Get short git hash
GIT_HASH=$(git rev-parse --short HEAD)

# Add git hash to Info.plist
echo "Adding Git hash ($GIT_HASH) to Info.plist..."
/usr/libexec/PlistBuddy -c "Add :GitCommitHash string $GIT_HASH" "$APP_BUNDLE_NAME/Contents/Info.plist" || \
/usr/libexec/PlistBuddy -c "Set :GitCommitHash $GIT_HASH" "$APP_BUNDLE_NAME/Contents/Info.plist"

# Create NDI framework structure
mkdir -p "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework/Versions/A/Resources"
mkdir -p "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework/Versions/A/Headers"

# Create framework Info.plist (directly in framework root)
cat > "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework/Versions/A/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NDI</string>
    <key>CFBundleIdentifier</key>
    <string>com.newtek.ndi.framework</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NDI</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>5.5.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string></string>
</dict>
</plist>
EOF

# Copy dylib to Versions/A only (not duplicated in root)
ditto "/Library/NDI SDK for Apple/lib/macOS/libndi.dylib" "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework/Versions/A/NDI"

# Copy headers to Headers directory
ditto "/Library/NDI SDK for Apple/include/Processing.NDI.Lib.h" "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework/Versions/A/Headers/"

# Create correct symlinks (relative to framework root)
cd "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework"
ln -sfh A Versions/Current
ln -sfh Versions/Current/NDI NDI
ln -sfh Versions/Current/Resources Resources
ln -sfh Versions/Current/Headers Headers
cd ../../../..

# Update install name
install_name_tool -change @rpath/libndi.dylib @executable_path/../Frameworks/NDI.framework/NDI "$APP_BUNDLE_NAME/Contents/MacOS/LiveStreamTally"

# Clean up iconset
rm -rf "$ICONSET"

# Code sign the NDI framework dylib first (if using a signing identity)
if [ "$SIGN_IDENTITY" != "-" ]; then
    echo "Signing NDI framework dylib..."
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE_NAME/Contents/Frameworks/NDI.framework/Versions/A/NDI"
fi

# Code sign the app with entitlements
echo "Attempting to sign with identity: $SIGN_IDENTITY"
# Sign the app bundle
# Note: The identifier here should match Info.plist and the registered App ID
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" --entitlements LiveStreamTally.entitlements --identifier com.richardbolt.livestreamtally "$APP_BUNDLE_NAME"
codesign -vv -d "$APP_BUNDLE_NAME"

echo "App bundle created at $APP_BUNDLE_NAME"
echo "Run with: open \"$APP_BUNDLE_NAME\"" 