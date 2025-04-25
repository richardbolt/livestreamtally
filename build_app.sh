#!/bin/bash

# Exit on error
set -e

# Optional: Set your Apple Developer ID here
SIGN_IDENTITY="${SIGN_IDENTITY:-"-"}" # Use "-" for ad-hoc

echo "Building YouTube Live Status app..."

# Clean up any existing app bundle
rm -rf YouTubeLiveStatus.app

# Create iconset directory
ICONSET="YouTubeLiveStatus.app/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET"

# Copy and rename icons
echo "Creating iconset..."
echo "Copying icons from Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/"
ls -la Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/
echo "To $ICONSET"
ls -la "$ICONSET" || echo "Iconset directory is empty"

cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_16x16.png "$ICONSET/icon_16x16.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_16x16@2x.png "$ICONSET/icon_16x16@2x.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_32x32.png "$ICONSET/icon_32x32.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_32x32@2x.png "$ICONSET/icon_32x32@2x.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_128x128.png "$ICONSET/icon_128x128.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_128x128@2x.png "$ICONSET/icon_128x128@2x.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_256x256.png "$ICONSET/icon_256x256.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_256x256@2x.png "$ICONSET/icon_256x256@2x.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_512x512.png "$ICONSET/icon_512x512.png"
cp Sources/YouTubeLiveStatus/Resources/AppIcon.appiconset/icon_512x512@2x.png "$ICONSET/icon_512x512@2x.png"

echo "Iconset contents after copying:"
ls -la "$ICONSET"

# Convert iconset to icns
echo "Converting iconset to icns..."
iconutil -c icns -o "YouTubeLiveStatus.app/Contents/Resources/AppIcon.icns" "$ICONSET"

# Build app in release mode
echo "Building app in release mode..."
swift build -c release

# Create app bundle structure
mkdir -p YouTubeLiveStatus.app/Contents/{MacOS,Resources,Frameworks}

# Copy executable
cp .build/release/YouTubeLiveStatus YouTubeLiveStatus.app/Contents/MacOS/

# Copy Info.plist
cp Info.plist YouTubeLiveStatus.app/Contents/

# Create NDI framework structure
mkdir -p YouTubeLiveStatus.app/Contents/Frameworks/NDI.framework/Versions/A/{Resources,Headers}

# Create framework Info.plist (directly in framework root)
cat > YouTubeLiveStatus.app/Contents/Frameworks/NDI.framework/Versions/A/Resources/Info.plist << EOF
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
ditto "/Library/NDI SDK for Apple/lib/macOS/libndi.dylib" "YouTubeLiveStatus.app/Contents/Frameworks/NDI.framework/Versions/A/NDI"

# Copy headers to Headers directory
ditto "/Library/NDI SDK for Apple/include/Processing.NDI.Lib.h" "YouTubeLiveStatus.app/Contents/Frameworks/NDI.framework/Versions/A/Headers/"

# Create correct symlinks (relative to framework root)
cd YouTubeLiveStatus.app/Contents/Frameworks/NDI.framework
ln -sfh A Versions/Current
ln -sfh Versions/Current/NDI NDI
ln -sfh Versions/Current/Resources Resources
ln -sfh Versions/Current/Headers Headers
cd ../../../..

# Update install name
install_name_tool -change @rpath/libndi.dylib @executable_path/../Frameworks/NDI.framework/NDI YouTubeLiveStatus.app/Contents/MacOS/YouTubeLiveStatus

# Sign the NDI framework
#codesign --force --sign - --entitlements YouTubeLiveStatus.entitlements YouTubeLiveStatus.app/Contents/Frameworks/NDI.framework

# Clean up iconset
rm -rf "$ICONSET"

# Code sign the app with entitlements
echo "Code signing with entitlements..."
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" --entitlements YouTubeLiveStatus.entitlements --identifier com.youtubelivestatus.app YouTubeLiveStatus.app

# Verify code signing
echo "Verifying code signing..."
codesign -vv -d YouTubeLiveStatus.app

echo "App bundle created at YouTubeLiveStatus.app"
echo "Run with: open YouTubeLiveStatus.app" 