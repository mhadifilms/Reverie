# Reverie Audit Learnings (Working Notes)

Date: 2026-02-23
Workspace: /Users/livestream/Documents/GitHub/Reverie

## Scope
- Full code and feature audit across app target, widget extension, models/services/viewmodels/views, config, entitlements, and docs.
- Identify built, half-built, mentioned/planned, and missing features.
- Flag major bugs, stale/deprecated code, risky architecture, and hacky/fragile implementations.

## Build / Runtime Validation
- Clean macOS build succeeds with warnings: `xcodebuild -scheme Reverie -destination generic/platform=macOS clean build`.
- Warnings include:
  - unnecessary `nonisolated(unsafe)` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Utilities/Constants.swift:13`
  - `Timer` non-Sendable capture warning in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/AudioPlayer.swift:417`
  - unreachable catches in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/ComprehensiveTestView.swift:159`
  - async misuse in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/StorageManager.swift:319`
  - async misuse in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/YouTubeResolver.swift:138`
- Codesign entitlement dump for built app currently shows only `com.apple.security.get-task-allow` (no app group/iCloud entitlements).

## Confirmed High-Risk Findings
- Entitlements mismatch:
  - App target sets `CODE_SIGN_ENTITLEMENTS = ""` in `/Users/livestream/Documents/GitHub/Reverie/Reverie.xcodeproj/project.pbxproj:276` and `:324`.
  - App entitlements file exists with app groups/iCloud keys in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Reverie.entitlements:17` and `:21`.
- Widget/app shared container likely non-functional:
  - Shared defaults suite `group.com.reverie.shared` used in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/AudioPlayer.swift:383` and `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgets.swift:57`.
  - Extension has no explicit entitlements file in repo; app target entitlements are not applied.
- App Intents actions are not wired end-to-end:
  - Intents post local notifications in `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/AppIntent.swift:28` and `/Users/livestream/Documents/GitHub/Reverie/Reverie/Utilities/ReverieAppShortcuts.swift:28`.
  - No app observers found for `TogglePlayPause`, `SkipToNext`, `SkipToPrevious`, `PauseForFocus`.
- Download concurrency bug:
  - `processDownloadQueue` awaits each download inline in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/DownloadManager.swift:150`, which serializes queue despite `maxConcurrentDownloads`.
- Queue duplication risk:
  - queue appends without dedupe in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/DownloadManager.swift:85` and `:112`; only `activeDownloads` is checked.
- Live Activity / Widget implementation split and inconsistency:
  - App has `NowPlayingAttributes` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/ReverieL iveActivity.swift:22`.
  - Extension live activity is template emoji implementation in `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgetsLiveActivity.swift:12` and `:27`.
  - Two separate now-playing widget codebases exist in app and extension targets.
- Storage migration state check appears ineffective:
  - View compares `saveToiCloud` vs `currentLocation` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Settings/StorageManagementView.swift:80`.
  - `getCurrentStorageLocation()` returns same preference backing (`saveToiCloud`) in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/StorageManager.swift:219`.
- Security posture issue:
  - ATS allows arbitrary loads in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Info.plist:12`.

## Architecture / Product-Behavior Learnings
- Core app shell:
  - `NavigationSplitView` (macOS) + `TabView` (iOS) with shared `AudioPlayer` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/ContentView.swift:25` and `:67`.
  - Always-on bottom mini-player via `NowPlayingBar` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/ContentView.swift:63` and `:88`.
- Library features:
  - Playlists + downloaded songs sections, sorting, add/remove, import sheet, create/edit custom playlists in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/LibraryView.swift`.
- Import flow:
  - Import sheet parses URL, then review screen performs YouTube matching before confirmation in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/ImportPlaylistSheet.swift:206` and `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/SpotifyImportReviewView.swift:227`.
- Search flow:
  - Debounced YouTube Music search, recent searches, per-result download/play in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Search/SearchView.swift:52` and `/Users/livestream/Documents/GitHub/Reverie/Reverie/ViewModels/SearchViewModel.swift:149`.
- Playback:
  - AVAudioEngine + remote command center + now playing metadata + waveform metering in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/AudioPlayer.swift`.

## Stale / Half-Built / Drift Signals
- README drift:
  - references missing `SETUP.md` in `/Users/livestream/Documents/GitHub/Reverie/README.md:59`.
  - marks features as future that already have substantial code (mini player/widgets/now playing).
- Empty placeholder folder:
  - `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Player` is empty.
- Legacy model appears unused:
  - `/Users/livestream/Documents/GitHub/Reverie/Reverie/Item.swift`.
- Test/debug views are shipped in main target source tree:
  - `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/TestImportView.swift`
  - `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/TestYouTubeView.swift`
  - `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/ComprehensiveTestView.swift`
  - `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Search/TestSearchView.swift`
- Template residue in widget extension:
  - timer control sample in `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgetsControl.swift`.
- Significant debug logging and `try?` suppression across production services/view models (esp. download/import paths).

## Additional Confirmed Bugs / Gaps
- Spotify URI acceptance mismatch:
  - UI accepts `spotify:playlist:` and `spotify:album:` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/ImportPlaylistSheet.swift:223`.
  - Parser entrypoint only branches on `"/playlist/"` and `"/album/"` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/SpotifyParser.swift:52`.
  - Result: accepted URI forms can fail with unsupported URL type.
- Playback queue behavior inconsistency:
  - Many play actions load a single track directly (e.g. `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Library/LibraryView.swift:309`, `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Search/SearchView.swift:489`) without queue setup.
  - Next/previous controls exist in UI and audio service (`/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/AudioPlayer.swift:277`) but often have no useful queue context.
- End-of-track progression appears missing:
  - `scheduleFile` uses `completionHandler: nil` in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/AudioPlayer.swift:175`.
  - No explicit auto-advance/track-finished state transition logic observed.
- Multiple timer risk in playback clock:
  - `startTimeUpdates()` schedules a new repeating timer each play call (`/Users/livestream/Documents/GitHub/Reverie/Reverie/Services/AudioPlayer.swift:409`) without holding a single timer reference.
- Playlist deletion side effects:
  - Deleting playlist from library invokes `/Users/livestream/Documents/GitHub/Reverie/Reverie/ViewModels/LibraryViewModel.swift:219`, which deletes downloaded files for every track in that playlist regardless of whether track is shared with another playlist.
- Orphan/stale records risk:
  - Imported playlist deletion removes playlist, but tracks are not deleted from SwiftData; they can remain orphaned metadata.

## Widget / Live Activity State
- App target contains full widget implementation in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/ReverieWidget.swift`.
- Widget extension also contains nearly identical implementation in `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgets.swift`.
- Extension bundle registers only `ReverieNowPlayingWidget` (`/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgetsBundle.swift:14`).
- Extension has additional template control/live-activity files not registered:
  - `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgetsControl.swift`
  - `/Users/livestream/Documents/GitHub/Reverie/ReverieWidgets/ReverieWidgetsLiveActivity.swift`
- App has separate live activity views in `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/ReverieL iveActivity.swift`, but live activities should be hosted via widget extension `ActivityConfiguration`.

## Feature-State Snapshot (working)
- Implemented and usable:
  - Playlist/album import UI + review flow.
  - YouTube Music search and per-track download from search.
  - Offline file storage and playback.
  - Library browsing, playlist cards, song sorting.
  - Mini-player and expanded now-playing sheet.
- Partially implemented / fragile:
  - Widget controls and app intents (not wired end-to-end).
  - iCloud/app group storage sync path (entitlement/config mismatch).
  - Live activities (split implementation, template residue, not coherently registered).
  - Focus filter (intent writes defaults but no app behavior consumes it).
  - Handoff metadata publishing exists, but no continuation handling found.
- Planned/mentioned but missing in product reality:
  - MusicBrainz integration (constants/model fields only).
  - Dedicated Player module (`/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/Player` is empty).
  - Reliable API fallback flow for Spotify imports in user UI (method exists but no user path).

## Hygiene / Maintainability Notes
- Project includes numerous debug `print` statements and broad `try?` error suppression in core flows (import/search/download/playback).
- `/Users/livestream/Documents/GitHub/Reverie/.gitignore` only ignores `build/`.
- `/Users/livestream/Documents/GitHub/Reverie/Reverie.xcodeproj/project.pbxproj` includes `README.md` in app resources (`README.md in Resources`).
- Filename typo/space likely accidental: `/Users/livestream/Documents/GitHub/Reverie/Reverie/Views/ReverieL iveActivity.swift`.
