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
    1. You can use a Channel Handle
4. Build and run the app:
   ```bash
   ./build_app.sh
   open YouTubeLiveStatus.app
   ```

## Development

This project uses Swift Package Manager for dependency management. To work on the project:

1. Clone the repository
2. Open the project in Xcode or your preferred editor
3. Run `./build_app.sh` to build the project
4. Run `OS_ACTIVITY_MODE=debug open YouTubeLiveStatus.app` to run the app in debug mode

To stream application logs:

```bash
log stream --predicate 'subsystem == "com.youtubelivestatus.app"' --level debug
```


## License

This application is released under the MIT License. See the [LICENSE](LICENSE) file for details.

### Third-Party Components

- **NDI®**: This software uses NDI® technology, which is a registered trademark of Vizrt Group. Use of the NDI SDK is subject to the [NDI SDK License Agreement](https://www.ndi.tv/license/).
- **Google APIs for Swift**: This project uses Google's API client libraries which are licensed under Apache 2.0. 