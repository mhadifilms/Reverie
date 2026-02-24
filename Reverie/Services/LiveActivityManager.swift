//
//  LiveActivityManager.swift
//  Reverie
//
//  Created by Claude on 2/23/26.
//

#if os(iOS)
import ActivityKit
import Foundation
import os

/// Shared Activity Attributes for Now Playing Live Activity.
/// Defined identically in both app and widget extension targets.
struct NowPlayingAttributes: ActivityAttributes {
    var trackTitle: String
    var artistName: String
    var albumArtData: Data

    public struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var progress: Double      // 0.0 – 1.0
        var elapsedSeconds: Int
        var totalSeconds: Int
    }
}

/// Manages Now Playing Live Activity lifecycle from the app side.
/// Start on play, update on state changes, end on explicit stop.
@MainActor
@Observable
class LiveActivityManager {

    static let shared = LiveActivityManager()

    private let logger = Logger(subsystem: "com.reverie", category: "liveActivity")
    private var currentActivity: Activity<NowPlayingAttributes>?

    // MARK: - Start

    func startActivity(trackTitle: String, artistName: String, albumArtData: Data?, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities not enabled by user")
            return
        }

        // End any existing activity before starting a new one
        endActivity()

        let attributes = NowPlayingAttributes(
            trackTitle: trackTitle,
            artistName: artistName,
            albumArtData: albumArtData ?? Data()
        )

        let initialState = NowPlayingAttributes.ContentState(
            isPlaying: true,
            progress: 0,
            elapsedSeconds: 0,
            totalSeconds: totalSeconds
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            logger.info("Started Live Activity for: \(trackTitle)")
        } catch {
            logger.error("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update

    func updateActivity(isPlaying: Bool, progress: Double, elapsed: Int, total: Int) {
        guard let activity = currentActivity else { return }

        let state = NowPlayingAttributes.ContentState(
            isPlaying: isPlaying,
            progress: progress,
            elapsedSeconds: elapsed,
            totalSeconds: total
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - End

    /// Ends the current Live Activity. Called on explicit stop (not pause).
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        logger.info("Ended Live Activity")
    }

    // MARK: - Track Change

    /// Convenience: end current + start new for track changes.
    func switchTrack(trackTitle: String, artistName: String, albumArtData: Data?, totalSeconds: Int) {
        endActivity()
        startActivity(
            trackTitle: trackTitle,
            artistName: artistName,
            albumArtData: albumArtData,
            totalSeconds: totalSeconds
        )
    }
}
#endif
