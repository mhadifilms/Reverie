//
//  DailyMixService.swift
//  Reverie
//
//  Keeps a single persistent "Daily Mix" playlist in SwiftData up-to-date.
//  Regenerates the track list once per calendar day using the same
//  RecommendationEngine that powers the home-page shelves — picks from
//  the user's top artist + their onboarding genres + cold-start diversity
//  so the mix feels fresh day-to-day without ever being random.
//
//  The playlist record itself is permanent (survives app relaunches and
//  shows on the Library's Playlists grid); only its `tracks` are refreshed.
//  Tracks default to `.notDownloaded` — tapping one streams via the
//  unified AudioPlayer.playTrack.
//

import Foundation
import SwiftData
import OSLog

@MainActor
final class DailyMixService {

    static let playlistName = "Daily Mix"
    private static let lastGeneratedKey = "dailyMix.lastGeneratedDate"

    private let logger = Logger(subsystem: "com.reverie", category: "daily-mix")
    private let engine = RecommendationEngine()

    /// Ensures today's Daily Mix exists and is fresh. Safe to call on every
    /// app launch — will no-op if today's mix was already generated.
    func ensureDailyMix(modelContext: ModelContext) async {
        let today = Calendar.current.startOfDay(for: Date())

        if let last = UserDefaults.standard.object(forKey: Self.lastGeneratedKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            logger.info("Daily Mix already generated today — skipping")
            return
        }

        logger.info("Generating Daily Mix for \(today, privacy: .public)")

        let shelves = await engine.generateShelves(
            modelContext: modelContext,
            tuningFilters: TuningFilters()
        )

        // Round-robin across shelves so the mix is varied — instead of
        // "30 tracks from one shelf" we take item 0 from shelf A, 0 from B,
        // 0 from C, then 1 from A, 1 from B, etc.
        let lanes = shelves.map(\.items)
        var picked: [ShelfItem] = []
        var index = 0
        while picked.count < 30 {
            let before = picked.count
            for lane in lanes where index < lane.count {
                picked.append(lane[index])
                if picked.count >= 30 { break }
            }
            if picked.count == before { break }
            index += 1
        }

        // Dedupe by videoID (library tracks and remote recs can collide).
        var seen: Set<String> = []
        let unique = picked.filter { item in
            let key = item.videoID ?? item.id
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        guard !unique.isEmpty else {
            logger.info("Daily Mix: no candidates available — leaving prior mix in place")
            return
        }

        do {
            try rebuildPlaylist(with: unique, modelContext: modelContext)
            UserDefaults.standard.set(today, forKey: Self.lastGeneratedKey)
            logger.info("Daily Mix built with \(unique.count, privacy: .public) tracks")
        } catch {
            logger.error("Daily Mix rebuild failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Playlist mutation

    private func rebuildPlaylist(with items: [ShelfItem], modelContext: ModelContext) throws {
        // Find-or-create the playlist record.
        let name = Self.playlistName
        let descriptor = FetchDescriptor<ReveriePlaylist>(
            predicate: #Predicate<ReveriePlaylist> { $0.name == name }
        )
        let existing = try modelContext.fetch(descriptor).first
        let playlist = existing ?? ReveriePlaylist(name: name, isCustom: true)
        if existing == nil {
            modelContext.insert(playlist)
        }

        // For each incoming shelf item, find-or-create a ReverieTrack and
        // link it to the playlist. We leave any pre-existing tracks that
        // were in the previous mix untouched — they remain independently
        // usable; only the playlist membership gets refreshed.
        var newTracks: [ReverieTrack] = []
        for item in items {
            if let library = item.libraryTrack {
                newTracks.append(library)
                continue
            }
            guard let videoID = item.videoID else { continue }

            // Re-use an existing ReverieTrack for this videoID if we've
            // already saved one (from a prior Daily Mix or a user download).
            let existingDescriptor = FetchDescriptor<ReverieTrack>(
                predicate: #Predicate<ReverieTrack> { $0.youtubeVideoID == videoID }
            )
            if let found = try? modelContext.fetch(existingDescriptor).first {
                newTracks.append(found)
                continue
            }

            let track = ReverieTrack(
                title: item.title,
                artist: item.artist,
                album: "",
                durationSeconds: 0,
                albumArtData: item.artData,
                youtubeVideoID: videoID,
                downloadState: .notDownloaded
            )
            modelContext.insert(track)
            newTracks.append(track)
        }

        // Replace the playlist's tracks. ReveriePlaylist.tracks is a
        // many-to-many relationship, so we can just assign.
        playlist.tracks = newTracks
        playlist.dateImported = Date()

        // If the playlist had no cover yet, use the first track's art.
        if playlist.coverArtData == nil {
            playlist.coverArtData = newTracks.first(where: { $0.albumArtData != nil })?.albumArtData
        }

        try modelContext.save()
    }
}
