# Reverie 🎵

A beautiful, offline-first music player for macOS and iOS. Import Spotify playlists, download audio from YouTube, and play everything offline with a gorgeous native UI.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-blue)
![Swift](https://img.shields.io/badge/swift-6.0-orange)
![License](https://img.shields.io/badge/license-Personal%20Use-green)

---

## Features

- 🎵 **Import Spotify Playlists** - Paste any public Spotify playlist URL
- 📥 **Download for Offline** - Downloads highest quality audio from YouTube (m4a/AAC)
- 🎧 **Beautiful Native UI** - Modern macOS design with sidebar navigation, hover effects
- 🔒 **Completely Offline** - Music plays forever, no internet needed after download
- 🎮 **Lock Screen Controls** - Play/pause/skip from Lock Screen (iOS/macOS)
- 💾 **Local or iCloud** - Store files locally or sync via iCloud Drive
- 🎨 **Album Art** - Automatic cover art from Spotify
- 📊 **Progress Tracking** - Real-time download progress with queuing system
- 🚀 **Zero Config** - No accounts, no API keys, no tracking

---

## Screenshots

### macOS - Sidebar Navigation
Beautiful three-pane layout with Library, Search, and Settings.

### Playlist View
Large album art, download progress, and batch download support.

### Import Flow
Simple sheet to paste Spotify URLs and import instantly.

---

## Quick Start

### Prerequisites

- **Xcode 16+** (for iOS 26 / macOS support)
- **macOS 15+** or **iOS 26+**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Reverie.git
   cd Reverie
   ```

2. **Open in Xcode**
   ```bash
   open Reverie.xcodeproj
   ```

3. **Add YouTubeKit dependency** (required)
   - File → Add Package Dependencies
   - URL: `https://github.com/alexeichhorn/YouTubeKit`
   - Version: `1.0.0` or higher

4. **Build and Run** (`Cmd + R`)

---

## How to Use

### Import a Spotify Playlist

1. Click **"Import Playlist"** button
2. Paste a Spotify playlist URL (e.g., `https://open.spotify.com/playlist/...`)
3. Wait for tracks to be imported
4. Playlist appears in your Library with all tracks listed

### Download Music

**Option 1: Download All**
- Open playlist detail view
- Click **"Download All Songs"** button

**Option 2: Individual Tracks**
- Click the download button (↓) next to any track
- Up to 3 tracks download concurrently

### Play Music

- Click the play button (▶) on any downloaded track
- Music plays with full Lock Screen integration
- Use next/previous buttons to navigate queue

---

## Architecture

### Tech Stack

- **SwiftUI** - Modern declarative UI
- **SwiftData** - Local database for playlists/tracks
- **AVFoundation** - Audio playback engine
- **URLSession** - Networking and downloads
- **YouTubeKit** - YouTube stream extraction (only external dependency)

### Project Structure

```
Reverie/
├── Models/              # SwiftData models (Playlist, Track)
├── Services/            # Business logic (Spotify, YouTube, Download, Audio)
├── ViewModels/          # Observable view models
├── Views/               
│   ├── Library/         # Playlist and track views
│   ├── Search/          # Search interface
│   ├── Settings/        # Preferences
│   ├── Player/          # Now Playing (future)
│   └── Components/      # Reusable UI (AlbumArt, DownloadButton, etc.)
└── Utilities/           # Constants, HapticManager
```

### Data Flow

```
User pastes Spotify URL
    ↓
SpotifyParser extracts track list (HTML scraping)
    ↓
SwiftData stores playlist + tracks
    ↓
User taps "Download"
    ↓
DownloadManager queues download
    ↓
YouTubeResolver finds audio URL (cipher handling via YouTubeKit)
    ↓
URLSession downloads .m4a file
    ↓
StorageManager saves to disk
    ↓
Track marked as "downloaded"
    ↓
User taps "Play"
    ↓
AudioPlayer loads file from disk
    ↓
Playback with Lock Screen controls
```

---

## Testing

Reverie includes comprehensive test views:

- **TestImportView** - Test Spotify playlist parsing
- **TestYouTubeView** - Test YouTube audio resolution
- **ComprehensiveTestView** - Full end-to-end test (Import → Download → Play)

To access test views, temporarily swap them into `ContentView.swift`.

---

## Implementation Notes

### Spotify Parsing

Uses **pure Swift HTML parsing** to extract Spotify's embedded `__NEXT_DATA__` JSON blob from playlist pages. No API key required, works with any public playlist.

**Potential issues:** Spotify may change their HTML structure over time.  
**Fallback:** Spotify Web API with Client Credentials flow (requires free developer app).

### YouTube Resolution

Uses **YouTubeKit** to handle YouTube's signature cipher and n-parameter throttling. This is critical because:
- YouTube scrambles stream URLs with JavaScript-based ciphers
- These ciphers change regularly (sometimes weekly)
- Without proper descrambling, most videos won't work
- Downloads are throttled to ~50KB/s without n-parameter fix

YouTubeKit handles all this automatically with local extraction + remote fallback.

### Audio Format

Downloads **m4a (AAC)** at 128-256kbps from YouTube. This is:
- YouTube's native audio format (no transcoding needed)
- Apple's preferred format (plays natively on iOS/macOS)
- Small file size (~3-5MB per song)
- Excellent quality for streaming audio

No need for FLAC - you can't add fidelity that isn't in the source.

---

## Future Enhancements (Post-MVP)

- [ ] **Now Playing UI** - Full-screen view with waveform visualizer
- [ ] **MusicBrainz Search** - Search for songs without Spotify
- [ ] **Mini Player** - Persistent playback bar
- [ ] **Lyrics** - Synced lyrics display (via LRCLIB)
- [ ] **Apple Music Import** - Support Apple Music playlists
- [ ] **CarPlay** - Car integration
- [ ] **Widgets** - Home Screen widgets for iOS
- [ ] **iCloud Sync** - Sync library across devices

---

## Known Issues

1. **Spotify HTML Changes** - If Spotify updates their page structure, parsing may break
   - *Mitigation:* Implement Spotify Web API fallback
   
2. **YouTube Cipher Updates** - YouTubeKit handles this automatically
   - *Mitigation:* Keep YouTubeKit updated

3. **Large Playlists** - Playlists with 500+ songs may take time to download
   - *Current:* Progress tracking shows estimated time

---

## Contributing

This is a personal project, but feel free to:
- Report bugs via GitHub Issues
- Suggest features
- Fork and modify for your own use


---

## License

**Personal Use Only**

This software is provided for personal, educational use only. Not licensed for commercial distribution or use. See source code for component licenses (Swift standard library, AVFoundation, etc.).
