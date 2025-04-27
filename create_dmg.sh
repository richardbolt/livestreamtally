#!/usr/bin/env bash
set -e

APP_NAME="LiveStreamTally"
VOL_NAME="Live Stream Tally"
DMG_FINAL="dist/${APP_NAME}.dmg"
SRC_APP="${APP_NAME}.app"
TEMP_DIR="./tmp_dmg"

# Check if the app exists
if [ ! -d "${SRC_APP}" ]; then
    echo "Error: ${SRC_APP} not found"
    exit 1
fi

echo "Creating DMG for ${APP_NAME}..."

# Create temporary directory for DMG contents
mkdir -p "${TEMP_DIR}"

# Copy the app to the temporary directory
echo "Preparing DMG contents..."
cp -R "${SRC_APP}" "${TEMP_DIR}/"

# Create a symbolic link to /Applications
echo "Creating Applications symlink..."
ln -s /Applications "${TEMP_DIR}/Applications"

# Create the DMG directly from folder
echo "Creating DMG..."
hdiutil create -volname "${VOL_NAME}" -srcfolder "${TEMP_DIR}" -ov -format UDZO -o "${DMG_FINAL}"

# Clean up
echo "Cleaning up..."
rm -rf "${TEMP_DIR}"

echo "Created ${DMG_FINAL}" 