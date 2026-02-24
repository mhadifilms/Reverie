//
//  RecommendationEngine.swift
//  Reverie
//
//  Generates personalized music recommendations using on-device listening signals
//  and YouTube Music's radio/automix endpoints. All processing happens locally.
//

import Foundation
import SwiftData
import OSLog

/// A recommended track with metadata and relevance score
struct RecommendedTrack: Identifiable, Sendable {
    let id: String  // videoID
    let videoID: String
    let title: String
    let artist: String
    let thumbnailURL: URL?
    let score: Double  // 0.0 to 1.0
}

/// Tuning filters parsed from the user's natural language prompt
struct TuningFilters: Sendable {
    var includeGenres: [String] = []
    var excludeGenres: [String] = []
    var includeArtists: [String] = []
    var excludeArtists: [String] = []
    var eras: [String] = []        // e.g., "90s", "2000s"
    var moods: [String] = []       // e.g., "chill", "energetic"
}

@MainActor
class RecommendationEngine {

    private let logger = Logger(subsystem: "com.reverie", category: "recommendations")

    // MARK: - Public API

    /// Generates up to 20 recommended tracks based on listening history and tuning filters.
    func generateRecommendations(
        modelContext: ModelContext,
        tuningFilters: TuningFilters
    ) async -> [RecommendedTrack] {
        logger.info("Starting recommendation generation")

        // Stage 1: Seed generation from listening signals
        let seeds = await generateSeeds(modelContext: modelContext)
        guard !seeds.videoIDs.isEmpty else {
            logger.info("No seeds available — user needs more listening history")
            return []
        }

        // Stage 2: Fetch radio/automix candidates from YouTube Music
        let candidates = await fetchRadioCandidates(seeds: seeds)

        // Stage 3: Filter, deduplicate, and rank
        let libraryVideoIDs = getLibraryVideoIDs(modelContext: modelContext)
        let negativeArtists = getNegativeArtists(modelContext: modelContext)

        let ranked = rankCandidates(
            candidates,
            seeds: seeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters
        )

        logger.info("Generated \(ranked.count) recommendations")
        return Array(ranked.prefix(20))
    }

    // MARK: - Stage 1: Seed Generation

    private struct Seeds: Sendable {
        let videoIDs: [String]
        let artistNames: [String]
        let searchQueries: [String]
    }

    private func generateSeeds(modelContext: ModelContext) async -> Seeds {
        // Get top played tracks (by play count from signals)
        let playSignals = fetchSignals(
            modelContext: modelContext,
            types: ["play", "complete", "download"]
        )

        // Count plays per trackID
        var trackPlayCounts: [UUID: Int] = [:]
        var artistPlayCounts: [String: Int] = [:]
        for signal in playSignals {
            if let trackID = signal.trackID {
                trackPlayCounts[trackID, default: 0] += 1
            }
            if let artist = signal.artistName, !artist.isEmpty {
                artistPlayCounts[artist, default: 0] += 1
            }
        }

        // Sort tracks by play count, take top 20
        let topTrackIDs = trackPlayCounts
            .sorted { $0.value > $1.value }
            .prefix(20)
            .map(\.key)

        // Fetch videoIDs for top tracks
        var videoIDs: [String] = []
        for trackID in topTrackIDs {
            let descriptor = FetchDescriptor<ReverieTrack>(
                predicate: #Predicate { $0.id == trackID }
            )
            if let tracks = try? modelContext.fetch(descriptor),
               let track = tracks.first,
               let videoID = track.youtubeVideoID {
                videoIDs.append(videoID)
            }
        }

        // Top artists
        let topArtists = artistPlayCounts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map(\.key)

        // Recent search queries
        let searchSignals = fetchSignals(modelContext: modelContext, types: ["search"])
        let recentQueries = searchSignals
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
            .compactMap(\.query)

        logger.info("Seeds: \(videoIDs.count) videoIDs, \(topArtists.count) artists, \(recentQueries.count) queries")
        return Seeds(videoIDs: videoIDs, artistNames: Array(topArtists), searchQueries: recentQueries)
    }

    // MARK: - Stage 2: YouTube Music Radio

    private struct RadioCandidate: Sendable {
        let videoID: String
        let title: String
        let artist: String
        let thumbnailURL: URL?
        var seedCount: Int  // How many seeds surfaced this candidate
    }

    private func fetchRadioCandidates(seeds: Seeds) async -> [RadioCandidate] {
        var allCandidates: [String: RadioCandidate] = [:]

        // Limit to first 5 seeds to avoid excessive requests
        let seedVideoIDs = Array(seeds.videoIDs.prefix(5))

        await withTaskGroup(of: [RadioCandidate].self) { group in
            for videoID in seedVideoIDs {
                group.addTask {
                    await self.fetchRadioForVideo(videoID: videoID)
                }
            }

            for await candidates in group {
                for candidate in candidates {
                    if var existing = allCandidates[candidate.videoID] {
                        existing.seedCount += 1
                        allCandidates[candidate.videoID] = existing
                    } else {
                        allCandidates[candidate.videoID] = candidate
                    }
                }
            }
        }

        return Array(allCandidates.values)
    }

    /// Calls YouTube Music InnerTube /next endpoint to get radio/automix queue for a videoID.
    private func fetchRadioForVideo(videoID: String) async -> [RadioCandidate] {
        let url = URL(string: "https://music.youtube.com/youtubei/v1/next")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "videoId": videoID,
            "isAudioOnly": true,
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00"
                ]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return []
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            return parseRadioResponse(data: data)
        } catch {
            logger.error("Radio fetch failed for \(videoID): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Parses the InnerTube /next response to extract up-next and radio tracks.
    private func parseRadioResponse(data: Data) -> [RadioCandidate] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var candidates: [RadioCandidate] = []

        // Navigate: contents.singleColumnMusicWatchNextResultsRenderer.tabbedRenderer
        //   .watchNextTabbedResultsRenderer.tabs[0].tabRenderer.content
        //   .musicQueueRenderer.content.playlistPanelRenderer.contents
        guard let contents = json["contents"] as? [String: Any],
              let singleColumn = contents["singleColumnMusicWatchNextResultsRenderer"] as? [String: Any],
              let tabbedRenderer = singleColumn["tabbedRenderer"] as? [String: Any],
              let watchNext = tabbedRenderer["watchNextTabbedResultsRenderer"] as? [String: Any],
              let tabs = watchNext["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let content = tabRenderer["content"] as? [String: Any],
              let musicQueue = content["musicQueueRenderer"] as? [String: Any],
              let queueContent = musicQueue["content"] as? [String: Any],
              let playlistPanel = queueContent["playlistPanelRenderer"] as? [String: Any],
              let items = playlistPanel["contents"] as? [[String: Any]] else {
            return []
        }

        for item in items {
            guard let renderer = item["playlistPanelVideoRenderer"] as? [String: Any],
                  let videoId = renderer["videoId"] as? String else {
                continue
            }

            // Title
            var title = ""
            if let titleObj = renderer["title"] as? [String: Any],
               let runs = titleObj["runs"] as? [[String: Any]],
               let firstRun = runs.first,
               let text = firstRun["text"] as? String {
                title = text
            }

            // Artist from longBylineText
            var artist = ""
            if let byline = renderer["longBylineText"] as? [String: Any],
               let runs = byline["runs"] as? [[String: Any]],
               let firstRun = runs.first,
               let text = firstRun["text"] as? String {
                artist = text
            }

            // Thumbnail
            var thumbnailURL: URL?
            if let thumbnail = renderer["thumbnail"] as? [String: Any],
               let thumbnails = thumbnail["thumbnails"] as? [[String: Any]],
               let last = thumbnails.last,
               let urlStr = last["url"] as? String {
                thumbnailURL = URL(string: urlStr)
            }

            candidates.append(RadioCandidate(
                videoID: videoId,
                title: title,
                artist: artist,
                thumbnailURL: thumbnailURL,
                seedCount: 1
            ))
        }

        return candidates
    }

    // MARK: - Stage 3: Filtering & Ranking

    private func getLibraryVideoIDs(modelContext: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<ReverieTrack>()
        guard let tracks = try? modelContext.fetch(descriptor) else { return [] }
        return Set(tracks.compactMap(\.youtubeVideoID))
    }

    private func getNegativeArtists(modelContext: ModelContext) -> Set<String> {
        let skipSignals = fetchSignals(modelContext: modelContext, types: ["skip"])
        // Artists skipped quickly (< 30s) at least 3 times
        var skipCounts: [String: Int] = [:]
        for signal in skipSignals {
            if let artist = signal.artistName,
               let duration = signal.durationListened,
               duration < 30 {
                skipCounts[artist, default: 0] += 1
            }
        }
        return Set(skipCounts.filter { $0.value >= 3 }.map(\.key))
    }

    private func rankCandidates(
        _ candidates: [RadioCandidate],
        seeds: Seeds,
        libraryVideoIDs: Set<String>,
        negativeArtists: Set<String>,
        tuningFilters: TuningFilters
    ) -> [RecommendedTrack] {
        let familiarArtists = Set(seeds.artistNames.map { $0.lowercased() })
        let maxSeedCount = max(candidates.map(\.seedCount).max() ?? 1, 1)

        var results: [RecommendedTrack] = []

        for candidate in candidates {
            // Skip tracks already in library
            if libraryVideoIDs.contains(candidate.videoID) { continue }

            // Skip negative-signal artists
            if negativeArtists.contains(candidate.artist) { continue }

            // Apply tuning exclusions
            let lowerArtist = candidate.artist.lowercased()
            let lowerTitle = candidate.title.lowercased()
            let combined = "\(lowerTitle) \(lowerArtist)"

            if tuningFilters.excludeArtists.contains(where: { lowerArtist.contains($0.lowercased()) }) {
                continue
            }
            if tuningFilters.excludeGenres.contains(where: { combined.contains($0.lowercased()) }) {
                continue
            }

            // Frequency score (40%): how many seeds surfaced this
            let frequencyScore = Double(candidate.seedCount) / Double(maxSeedCount)

            // Artist familiarity score (30%): bonus if artist is already known
            let familiarityScore: Double = familiarArtists.contains(lowerArtist) ? 1.0 : 0.3

            // Recency bonus (30%): boost if matches recent search queries
            var recencyScore = 0.3  // base
            for query in seeds.searchQueries {
                if combined.contains(query.lowercased()) {
                    recencyScore = 1.0
                    break
                }
            }

            // Tuning inclusion bonus
            var tuningBonus = 0.0
            if tuningFilters.includeArtists.contains(where: { lowerArtist.contains($0.lowercased()) }) {
                tuningBonus += 0.15
            }
            if tuningFilters.includeGenres.contains(where: { combined.contains($0.lowercased()) }) {
                tuningBonus += 0.1
            }
            if tuningFilters.moods.contains(where: { combined.contains($0.lowercased()) }) {
                tuningBonus += 0.05
            }

            let composite = (frequencyScore * 0.4) + (familiarityScore * 0.3) + (recencyScore * 0.3) + tuningBonus
            let clamped = min(composite, 1.0)

            results.append(RecommendedTrack(
                id: candidate.videoID,
                videoID: candidate.videoID,
                title: candidate.title,
                artist: candidate.artist,
                thumbnailURL: candidate.thumbnailURL,
                score: clamped
            ))
        }

        // Sort by score descending
        results.sort { $0.score > $1.score }
        return results
    }

    // MARK: - Helpers

    private func fetchSignals(modelContext: ModelContext, types: [String]) -> [ListeningSignal] {
        let descriptor = FetchDescriptor<ListeningSignal>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        return all.filter { types.contains($0.signalType) }
    }
}
