#!/bin/bash

# Exit on error
set -e

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

# Copy NDI library
cp /Library/NDI\ SDK\ for\ Apple/lib/macOS/libndi.dylib YouTubeLiveStatus.app/Contents/Frameworks/
install_name_tool -change @rpath/libndi.dylib @executable_path/../Frameworks/libndi.dylib YouTubeLiveStatus.app/Contents/MacOS/YouTubeLiveStatus

# Clean up iconset
rm -rf "$ICONSET"

echo "App bundle created at YouTubeLiveStatus.app"
echo "Run with: open YouTubeLiveStatus.app" 