//
//  SignalCollector.swift
//  Reverie
//
//  Records user listening signals into SwiftData for on-device recommendations.
//  All data stays local — never leaves the device.
//

import Foundation
import SwiftData
import OSLog

@MainActor
@Observable
class SignalCollector {

    private let logger = Logger(subsystem: "com.reverie", category: "signals")

    // MARK: - Record Signals

    /// Records a play event. A full play is when the user listened to most of the track.
    func recordPlay(track: ReverieTrack, duration: TimeInterval, wasFullPlay: Bool, modelContext: ModelContext) {
        let signal = ListeningSignal(
            signalType: wasFullPlay ? "complete" : "play",
            trackID: track.id,
            artistName: track.artist,
            durationListened: duration,
            isFullPlay: wasFullPlay
        )
        modelContext.insert(signal)
        try? modelContext.save()
        logger.info("Recorded \(wasFullPlay ? "complete" : "play") signal for \(track.title, privacy: .public)")
    }

    /// Records a skip event. Skipping within the first 30s is a negative signal.
    func recordSkip(track: ReverieTrack, afterSeconds: TimeInterval, modelContext: ModelContext) {
        let signal = ListeningSignal(
            signalType: "skip",
            trackID: track.id,
            artistName: track.artist,
            durationListened: afterSeconds,
            isFullPlay: false
        )
        modelContext.insert(signal)
        try? modelContext.save()
        logger.info("Recorded skip signal for \(track.title, privacy: .public) after \(afterSeconds, privacy: .public)s")
    }

    /// Records a search query.
    func recordSearch(query: String, modelContext: ModelContext) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let signal = ListeningSignal(
            signalType: "search",
            query: trimmed
        )
        modelContext.insert(signal)
        try? modelContext.save()
        logger.info("Recorded search signal: \(trimmed, privacy: .public)")
    }

    /// Records a download event (strong positive signal).
    func recordDownload(track: ReverieTrack, modelContext: ModelContext) {
        let signal = ListeningSignal(
            signalType: "download",
            trackID: track.id,
            artistName: track.artist,
            isFullPlay: false
        )
        modelContext.insert(signal)
        try? modelContext.save()
        logger.info("Recorded download signal for \(track.title, privacy: .public)")
    }
}
