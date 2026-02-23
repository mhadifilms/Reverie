//
//  AppIntent.swift
//  ReverieWidgets
//
//  Created by Muhammad Hadi Yusufali on 2/22/26.
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
