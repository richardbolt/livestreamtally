# YouTube Live Status

A macOS application that displays a YouTube channel's live streaming status using NDI output. Perfect for streamers who want to monitor YouTube live status and integrate it with streaming software, like OBS or Wirefcast, that support NDI.

This is a niche app and you'll know if you need it!

## Features

- Real-time monitoring of a YouTube channel live status
- NDI output for integration with streaming software
- Dark mode support
- Native macOS app with modern SwiftUI interface

## Requirements

- macOS 13.0 or later
- [NDI Runtime](https://www.ndi.tv/tools/) installed
- [YouTube Data API v3 key](https://developers.google.com/youtube/v3/getting-started)

## Setup

1. Install the NDI Runtime from [NDI.tv](https://www.ndi.tv/tools/)
2. Get a YouTube Data API key from the [Google Cloud Console](https://console.cloud.google.com/)
3. Find your YouTube Channel ID
    1. You can use a Channel Handle
4. Build and run the app:
   ```bash
   make
   make run
   ```

## Development

This project uses Swift Package Manager for dependency management. To work on the project:

1. Clone the repository
2. Open the project in Xcode or your preferred editor
3. Run `make` or `make build` to build the project
4. Run `OS_ACTIVITY_MODE=debug make run` to run the app in debug mode

Available make commands:
```bash
make          # Clean and build the app
make clean    # Remove build artifacts
make build    # Build the app and create app bundle
make run      # Run the app
make sign     # Sign the app (use SIGN_IDENTITY env var to specify identity)
make package  # Create a distributable zip package
make test     # Run Swift tests
make logs     # Stream debug+ level logs from the app
make help     # Display help information
```

## License

This application is released under the MIT License. See the [LICENSE](LICENSE) file for details.

### Third-Party Components

- **NDI®**: This software uses NDI® technology, which is a registered trademark of Vizrt Group. Use of the NDI SDK is subject to the [NDI SDK License Agreement](https://www.ndi.tv/license/).
- **Google APIs for Swift**: This project uses Google's API client libraries which are licensed under Apache 2.0. 