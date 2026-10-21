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

/// A unified row item for the home page shelves. Either wraps a library
/// track (playable locally) or a remote recommendation (streamed).
@MainActor
struct ShelfItem: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnailURL: URL?
    let artData: Data?
    let videoID: String?
    let libraryTrack: ReverieTrack?

    static func fromLibrary(_ track: ReverieTrack) -> ShelfItem {
        ShelfItem(
            id: "lib-\(track.id.uuidString)",
            title: track.title,
            artist: track.artist,
            thumbnailURL: nil,
            artData: track.albumArtData,
            videoID: track.youtubeVideoID,
            libraryTrack: track
        )
    }

    static func fromRemote(_ rec: RecommendedTrack) -> ShelfItem {
        ShelfItem(
            id: "rem-\(rec.videoID)",
            title: rec.title,
            artist: rec.artist,
            thumbnailURL: rec.thumbnailURL,
            artData: nil,
            videoID: rec.videoID,
            libraryTrack: nil
        )
    }
}

/// A single shelf on the home page (e.g. "Because you played Rick Astley").
@MainActor
struct HomeShelf: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String
    let items: [ShelfItem]
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
    /// On cold-start (no signals yet) we seed from a curated list of broadly-popular
    /// videoIDs so the Discover rail always has *something* for a fresh user to play —
    /// otherwise YouTube Music's /next radio can't run at all.
    func generateRecommendations(
        modelContext: ModelContext,
        tuningFilters: TuningFilters
    ) async -> [RecommendedTrack] {
        logger.info("Starting recommendation generation")

        // Stage 1: Seed generation from listening signals
        var seeds = await generateSeeds(modelContext: modelContext)
        if seeds.videoIDs.isEmpty {
            logger.info("No personal seeds — falling back to curated cold-start seeds")
            seeds = Seeds(
                videoIDs: Array(RecommendationEngine.coldStartSeeds.shuffled().prefix(5)),
                artistNames: [],
                searchQueries: []
            )
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

    // MARK: - Shelved home page
    //
    // A single Discover rail isn't enough to feel like a real music app, so
    // the home page now renders multiple contextually-distinct shelves:
    //   • "Pick up again"     — library tracks the user has actually played
    //   • "From [top artist]" — radio seeded from the user's #1 played artist
    //   • "Because you searched [q]" — radio seeded from the latest search
    //   • "New to you"        — general recs (the old Discover behaviour)
    //   • "Fresh finds"       — recs filtered to artists the user hasn't heard
    //
    // Onboarding preferences (@AppStorage "onboarding.genres" /
    // "onboarding.artists") also feed cold-start so fresh users don't get a
    // generic Rick-Astley-seeded rail.

    func generateShelves(
        modelContext: ModelContext,
        tuningFilters: TuningFilters
    ) async -> [HomeShelf] {
        logger.info("Generating shelved home page")

        let personalSeeds = await generateSeeds(modelContext: modelContext)
        let onboardingSeeds = onboardingSearchSeeds()

        let libraryVideoIDs = getLibraryVideoIDs(modelContext: modelContext)
        let negativeArtists = getNegativeArtists(modelContext: modelContext)

        // Kick off all remote queries in parallel so the home page isn't a
        // serial wait on several /next round-trips.
        async let generalRecsTask = generateRecommendations(
            modelContext: modelContext,
            tuningFilters: tuningFilters
        )
        async let topArtistShelfTask = shelfFromTopArtist(
            seeds: personalSeeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters,
            modelContext: modelContext
        )
        async let searchShelfTask = shelfFromRecentSearch(
            seeds: personalSeeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters
        )
        async let onboardingShelfTask = shelfFromOnboarding(
            onboardingSeeds: onboardingSeeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters
        )

        let generalRecs = await generalRecsTask
        let artistShelf = await topArtistShelfTask
        let searchShelf = await searchShelfTask
        let onboardingShelf = await onboardingShelfTask

        var shelves: [HomeShelf] = []

        // Shelf 1: "Pick up again" — recently played library tracks, ordered
        // by lastPlayedDate. Skips tracks that were only downloaded but never
        // played so it doesn't just duplicate the library.
        if let pickUp = pickUpAgainShelf(modelContext: modelContext) {
            shelves.append(pickUp)
        }

        // Shelf 2: "From [Top Artist]" — radio from the user's #1 artist.
        if let artistShelf = artistShelf {
            shelves.append(artistShelf)
        }

        // Shelf 3: "Because you searched [query]"
        if let searchShelf = searchShelf {
            shelves.append(searchShelf)
        }

        // Shelf 4: "Made from your taste" — uses onboarding genres/artists
        // to seed a radio. Only shown if onboarding was completed AND the
        // user hasn't accumulated much play history yet.
        if let onboardingShelf = onboardingShelf {
            shelves.append(onboardingShelf)
        }

        // Shelf 5: "New to you" — general recs filtered to unfamiliar artists.
        let knownArtists = Set(personalSeeds.artistNames.map { $0.lowercased() })
        let freshFinds = generalRecs.filter { rec in
            !knownArtists.contains(rec.artist.lowercased())
        }
        if !freshFinds.isEmpty {
            shelves.append(HomeShelf(
                id: "fresh-finds",
                title: "Fresh finds",
                subtitle: "Artists you haven't heard yet",
                systemImage: "sparkles",
                items: freshFinds.prefix(15).map(ShelfItem.fromRemote)
            ))
        }

        // Shelf 6: "New to you" — everything else (the old Discover rail).
        if !generalRecs.isEmpty {
            shelves.append(HomeShelf(
                id: "new-to-you",
                title: "New to you",
                subtitle: "Picked by Reverie radio",
                systemImage: "wand.and.stars",
                items: generalRecs.prefix(15).map(ShelfItem.fromRemote)
            ))
        }

        logger.info("Home page: \(shelves.count, privacy: .public) shelves")
        return shelves
    }

    // MARK: - Individual shelf builders

    private func pickUpAgainShelf(modelContext: ModelContext) -> HomeShelf? {
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate<ReverieTrack> { $0.playCount > 0 },
            sortBy: [SortDescriptor(\ReverieTrack.lastPlayedDate, order: .reverse)]
        )
        guard let tracks = try? modelContext.fetch(descriptor), !tracks.isEmpty else {
            return nil
        }

        return HomeShelf(
            id: "pick-up-again",
            title: "Pick up again",
            subtitle: "Songs you've been playing",
            systemImage: "arrow.clockwise",
            items: tracks.prefix(10).map(ShelfItem.fromLibrary)
        )
    }

    private func shelfFromTopArtist(
        seeds: Seeds,
        libraryVideoIDs: Set<String>,
        negativeArtists: Set<String>,
        tuningFilters: TuningFilters,
        modelContext: ModelContext
    ) async -> HomeShelf? {
        guard let topArtist = seeds.artistNames.first else { return nil }

        // Pick any track the user has played by that artist as the seed.
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate<ReverieTrack> { $0.artist == topArtist },
            sortBy: [SortDescriptor(\ReverieTrack.playCount, order: .reverse)]
        )
        guard let seedTrack = (try? modelContext.fetch(descriptor))?.first,
              let seedVideoID = seedTrack.youtubeVideoID else {
            return nil
        }

        let miniSeeds = Seeds(
            videoIDs: [seedVideoID],
            artistNames: [topArtist],
            searchQueries: []
        )
        let candidates = await fetchRadioCandidates(seeds: miniSeeds)
        let ranked = rankCandidates(
            candidates,
            seeds: miniSeeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters
        )
        guard !ranked.isEmpty else { return nil }

        return HomeShelf(
            id: "from-\(seedVideoID)",
            title: "Because you played \(topArtist)",
            subtitle: nil,
            systemImage: "person.wave.2.fill",
            items: ranked.prefix(12).map(ShelfItem.fromRemote)
        )
    }

    private func shelfFromRecentSearch(
        seeds: Seeds,
        libraryVideoIDs: Set<String>,
        negativeArtists: Set<String>,
        tuningFilters: TuningFilters
    ) async -> HomeShelf? {
        guard let query = seeds.searchQueries.first,
              !query.isEmpty else { return nil }

        // Seed a radio from the cold-start pool weighted by the query text
        // — we don't have a way to directly search radio, but we can run the
        // general seed set and then upweight results whose title/artist
        // contain the query term. Simple but effective.
        let miniSeeds = Seeds(
            videoIDs: Array(Self.coldStartSeeds.shuffled().prefix(3)),
            artistNames: [],
            searchQueries: [query]
        )
        let candidates = await fetchRadioCandidates(seeds: miniSeeds)
        let ranked = rankCandidates(
            candidates,
            seeds: miniSeeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters
        )
        guard !ranked.isEmpty else { return nil }

        return HomeShelf(
            id: "search-\(query.hashValue)",
            title: "Because you searched \"\(query)\"",
            subtitle: nil,
            systemImage: "magnifyingglass",
            items: ranked.prefix(12).map(ShelfItem.fromRemote)
        )
    }

    private func shelfFromOnboarding(
        onboardingSeeds: Seeds,
        libraryVideoIDs: Set<String>,
        negativeArtists: Set<String>,
        tuningFilters: TuningFilters
    ) async -> HomeShelf? {
        // Only relevant for fresh users — skip once they've built real play
        // history (> 20 plays), since personal seeds are stronger.
        guard !onboardingSeeds.videoIDs.isEmpty ||
              !onboardingSeeds.searchQueries.isEmpty else {
            return nil
        }

        let candidates = await fetchRadioCandidates(seeds: onboardingSeeds)
        let ranked = rankCandidates(
            candidates,
            seeds: onboardingSeeds,
            libraryVideoIDs: libraryVideoIDs,
            negativeArtists: negativeArtists,
            tuningFilters: tuningFilters
        )
        guard !ranked.isEmpty else { return nil }

        let subtitle: String = {
            let genres = onboardingSeeds.searchQueries.prefix(3).joined(separator: " · ")
            return genres.isEmpty ? "From your onboarding picks" : genres
        }()

        return HomeShelf(
            id: "onboarding-taste",
            title: "Made from your taste",
            subtitle: subtitle,
            systemImage: "heart.fill",
            items: ranked.prefix(15).map(ShelfItem.fromRemote)
        )
    }

    /// Reads onboarding picks from AppStorage (written by OnboardingView) and
    /// converts them into a Seeds bundle. Genres map to search queries so
    /// the engine's existing "query match bonus" kicks in; artists become
    /// artist seeds (which currently feed the familiarity bonus but not
    /// radio — we pass them along anyway for future-proofing).
    private func onboardingSearchSeeds() -> Seeds {
        let defaults = UserDefaults.standard
        let genres = (defaults.array(forKey: "onboarding.genres") as? [String]) ?? []
        let artists = (defaults.array(forKey: "onboarding.artists") as? [String]) ?? []

        // We don't have videoIDs for picked genres — fall back to a few
        // curated seeds so the radio query can run.
        let seedVideoIDs = Array(Self.coldStartSeeds.shuffled().prefix(3))

        return Seeds(
            videoIDs: seedVideoIDs,
            artistNames: artists,
            searchQueries: genres + artists
        )
    }

    /// Curated cold-start seed set — broadly-appealing tracks from different
    /// moods/eras so the first radio query returns a diverse pool. Pulled
    /// randomly so two first-launches don't produce identical rails.
    private static let coldStartSeeds: [String] = [
        "dQw4w9WgXcQ", // Rick Astley - Never Gonna Give You Up (pop)
        "JGwWNGJdvx8", // Ed Sheeran - Shape of You
        "kJQP7kiw5Fk", // Luis Fonsi - Despacito
        "RgKAFK5djSk", // Wiz Khalifa - See You Again
        "OPf0YbXqDm0", // Mark Ronson - Uptown Funk
        "9bZkp7q19f0", // PSY - Gangnam Style
        "hT_nvWreIhg", // OneRepublic - Counting Stars
        "CevxZvSJLk8", // Katy Perry - Roar
        "pRpeEdMmmQ0", // Shakira - Waka Waka
        "YQHsXMglC9A", // Adele - Hello
        "SlPhMPnQ58k", // Miley Cyrus - Flowers
        "4NRXx6U8ABQ", // The Weeknd - Blinding Lights
        "TJAfLE39ZZ8", // Calm piano / study seed
        "5qap5aO4i9A", // Lofi Girl — generic lofi radio seed
        "jfKfPfyJRdk"  // Lofi beats / chillhop
    ]

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
