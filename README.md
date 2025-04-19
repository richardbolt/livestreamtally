# YouTube Live Status

A macOS application that displays your YouTube channel's live streaming status using NDI output. Perfect for streamers who want to monitor their YouTube live status and integrate it with streaming software that supports NDI.

## Features

- Real-time monitoring of YouTube channel live status
- NDI output for integration with streaming software
- Dark mode support
- Configurable refresh interval
- Native macOS app with modern SwiftUI interface

## Requirements

- macOS 13.0 or later
- [NDI Runtime](https://www.ndi.tv/tools/) installed
- YouTube Data API v3 key

## Setup

1. Install the NDI Runtime from [NDI.tv](https://www.ndi.tv/tools/)
2. Get a YouTube Data API key from the [Google Cloud Console](https://console.cloud.google.com/)
3. Find your YouTube Channel ID
4. Build and run the app:
   ```bash
   ./build_app.sh
   ```

## Development

This project uses Swift Package Manager for dependency management. To work on the project:

1. Clone the repository
2. Open the project in Xcode or your preferred editor
3. Run `swift build` to build the project
4. Run `swift run` to run the app in development mode

## License

[Your chosen license] 