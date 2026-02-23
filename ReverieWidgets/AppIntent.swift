//
//  AppIntent.swift
//  ReverieWidgets
//
//  Created by Muhammad Hadi Yusufali on 2/22/26.
//

import AppIntents
import WidgetKit

// MARK: - Play/Pause Intent

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var description = IntentDescription("Play or pause the current track in Reverie")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")
        let isPlaying = sharedDefaults?.bool(forKey: "isPlaying") ?? false

        // Toggle state in shared defaults so widget UI updates immediately
        sharedDefaults?.set(!isPlaying, forKey: "isPlaying")

        // Write pending action for the app to pick up on foreground
        sharedDefaults?.set("togglePlayPause", forKey: "pendingAction")

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

// MARK: - Skip Forward Intent

struct SkipForwardIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip to Next Track"
    static var description = IntentDescription("Skip to the next track in Reverie")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")
        sharedDefaults?.set("skipForward", forKey: "pendingAction")

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

// MARK: - Skip Backward Intent

struct SkipBackwardIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip to Previous Track"
    static var description = IntentDescription("Skip to the previous track in Reverie")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")
        sharedDefaults?.set("skipBackward", forKey: "pendingAction")

        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
