//
//  ReverieAppShortcuts.swift
//  Reverie
//
//  Created by Claude on 2/7/26.
//

import AppIntents
import SwiftUI

// MARK: - Play/Pause Intent

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var description = IntentDescription("Play or pause the current track in Reverie")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Access shared audio player state
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")
        let isPlaying = sharedDefaults?.bool(forKey: "isPlaying") ?? false
        
        // Toggle playback state
        sharedDefaults?.set(!isPlaying, forKey: "isPlaying")
        
        // Post notification to app to handle the action
        NotificationCenter.default.post(name: Notification.Name("TogglePlayPause"), object: nil)
        
        return .result(dialog: isPlaying ? "Paused" : "Playing")
    }
}

// MARK: - Skip Forward Intent

struct SkipForwardIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip to Next Track"
    static var description = IntentDescription("Skip to the next track in Reverie")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: Notification.Name("SkipToNext"), object: nil)
        return .result(dialog: "Skipping to next track")
    }
}

// MARK: - Skip Backward Intent

struct SkipBackwardIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip to Previous Track"
    static var description = IntentDescription("Skip to the previous track in Reverie")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: Notification.Name("SkipToPrevious"), object: nil)
        return .result(dialog: "Skipping to previous track")
    }
}

// MARK: - Search Music Intent

struct SearchMusicIntent: AppIntent {
    static var title: LocalizedStringResource = "Search for Music"
    static var description = IntentDescription("Search for music in Reverie")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Search Query")
    var query: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification with search query
        NotificationCenter.default.post(
            name: Notification.Name("SearchMusic"),
            object: nil,
            userInfo: ["query": query]
        )
        
        return .result(dialog: "Searching for \(query)")
    }
}

// MARK: - Play Playlist Intent

struct PlayPlaylistIntent: AppIntent {
    static var title: LocalizedStringResource = "Play a Playlist"
    static var description = IntentDescription("Play a specific playlist in Reverie")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Playlist Name")
    var playlistName: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: Notification.Name("PlayPlaylist"),
            object: nil,
            userInfo: ["playlistName": playlistName]
        )
        
        return .result(dialog: "Playing \(playlistName)")
    }
}

// MARK: - App Shortcuts Provider

struct ReverieAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayPauseIntent(),
            phrases: [
                "Play in \(.applicationName)",
                "Pause in \(.applicationName)",
                "Play or pause in \(.applicationName)",
                "Toggle playback in \(.applicationName)"
            ],
            shortTitle: "Play/Pause",
            systemImageName: "play.circle"
        )
        
        AppShortcut(
            intent: SkipForwardIntent(),
            phrases: [
                "Skip forward in \(.applicationName)",
                "Next track in \(.applicationName)",
                "Skip to next in \(.applicationName)"
            ],
            shortTitle: "Next Track",
            systemImageName: "forward.fill"
        )
        
        AppShortcut(
            intent: SkipBackwardIntent(),
            phrases: [
                "Skip backward in \(.applicationName)",
                "Previous track in \(.applicationName)",
                "Go back in \(.applicationName)"
            ],
            shortTitle: "Previous Track",
            systemImageName: "backward.fill"
        )
        
        AppShortcut(
            intent: SearchMusicIntent(),
            phrases: [
                "Search for music in \(.applicationName)",
                "Find a song in \(.applicationName)",
                "Search \(.applicationName)"
            ],
            shortTitle: "Search Music",
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: PlayPlaylistIntent(),
            phrases: [
                "Play my playlist in \(.applicationName)",
                "Start playlist in \(.applicationName)"
            ],
            shortTitle: "Play Playlist",
            systemImageName: "music.note.list"
        )
    }
}
