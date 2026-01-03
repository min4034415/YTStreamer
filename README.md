# YT Streamer

A native macOS app that streams YouTube audio to your local network. Perfect for playing music on vintage Macs like iMac G4.

## Features

- **Menu bar app** - Quick access from the menu bar
- **Full window UI** - Queue management, now playing, history
- **Network streaming** - Serve audio to any device on your network
- **YouTube support** - Paste any YouTube URL

## Setup in Xcode

### 1. Create New Project

1. Open Xcode
2. File → New → Project
3. Select **macOS** → **App**
4. Product Name: `YTStreamer`
5. Interface: **XIB** (we use programmatic UI)
6. Language: **Swift**
7. Uncheck "Use Core Data"

### 2. Copy Source Files

Copy the contents of `YTStreamer/` into your Xcode project:

```
YTStreamer/
├── App/
│   └── AppDelegate.swift
├── Views/
│   ├── MenuBarViewController.swift
│   └── MainWindowController.swift
├── Models/
│   ├── Track.swift
│   └── History.swift
├── Services/
│   ├── YouTubeDownloader.swift
│   ├── AudioConverter.swift
│   ├── HTTPServer.swift
│   ├── NetworkInfo.swift
│   └── StreamManager.swift
├── Utilities/
│   ├── ProcessRunner.swift
│   └── BundledTools.swift
├── Resources/
│   ├── yt-dlp       (download separately)
│   └── ffmpeg       (download separately)
├── Info.plist
└── YTStreamer.entitlements
```

### 3. Download Binaries

Download and add to `Resources/`:

**yt-dlp:**
```bash
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o Resources/yt-dlp
chmod +x Resources/yt-dlp
```

**ffmpeg:**
```bash
# Download from https://evermeet.cx/ffmpeg/
# Or use Homebrew version temporarily
cp /opt/homebrew/bin/ffmpeg Resources/ffmpeg
```

### 4. Configure Project

1. **Delete** default `Main.storyboard` and `ViewController.swift`
2. In **Info.plist**: Remove `NSMainStoryboardFile` entry
3. Add `@main` attribute to `AppDelegate.swift` (already included)
4. Add binaries to **Copy Bundle Resources** build phase

### 5. Signing & Entitlements

1. Select project → Signing & Capabilities
2. Disable sandbox (required for running bundled binaries)
3. Add entitlements file to build settings

### 6. Build & Run

Press ⌘R to build and run!

## Usage

1. Click the menu bar icon (🎵)
2. Paste a YouTube URL
3. Wait for download & conversion
4. Copy the stream URL
5. Open on any device: `http://YOUR_IP:8000/stream.mp3`

## Architecture

```
┌─────────────────┐
│   AppDelegate   │ ← Menu bar setup
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───┴───┐ ┌───┴───┐
│Popover│ │Window │ ← UI
└───┬───┘ └───┬───┘
    │         │
    └────┬────┘
         │
┌────────┴────────┐
│  StreamManager  │ ← Coordinates everything
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───┴───┐ ┌───┴───┐
│yt-dlp │ │ffmpeg │ ← Download & convert
└───────┘ └───────┘
         │
    ┌────┴────┐
    │HTTPServer│ ← Serve to network
    └──────────┘
```

## Requirements

- macOS 12.0+
- Xcode 14+
- yt-dlp binary
- ffmpeg binary

## License

MIT
