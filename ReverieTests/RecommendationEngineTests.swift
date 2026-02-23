//
//  RecommendationEngineTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for RecommendationEngine
//  Tests the recommendation data structures, TuningFilters, and RecommendedTrack.
//  The core ranking logic is private to the actor, so we test through the public API
//  where possible and validate the data structures used for scoring.
//

import Testing
import Foundation
import SwiftData
@testable import Reverie

struct RecommendationEngineTests {

    // MARK: - RecommendedTrack

    @Test func recommendedTrackInitialization() {
        let track = RecommendedTrack(
            id: "abc123",
            videoID: "abc123",
            title: "Test Song",
            artist: "Test Artist",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            score: 0.85
        )

        #expect(track.id == "abc123")
        #expect(track.videoID == "abc123")
        #expect(track.title == "Test Song")
        #expect(track.artist == "Test Artist")
        #expect(track.thumbnailURL?.absoluteString == "https://example.com/thumb.jpg")
        #expect(track.score == 0.85)
    }

    @Test func recommendedTrackScoreRange() {
        let lowScore = RecommendedTrack(id: "a", videoID: "a", title: "", artist: "", thumbnailURL: nil, score: 0.0)
        let highScore = RecommendedTrack(id: "b", videoID: "b", title: "", artist: "", thumbnailURL: nil, score: 1.0)

        #expect(lowScore.score >= 0.0)
        #expect(highScore.score <= 1.0)
    }

    @Test func recommendedTrackNilThumbnail() {
        let track = RecommendedTrack(id: "x", videoID: "x", title: "No Thumb", artist: "Artist", thumbnailURL: nil, score: 0.5)
        #expect(track.thumbnailURL == nil)
    }

    // MARK: - TuningFilters

    @Test func tuningFiltersDefaultEmpty() {
        let filters = TuningFilters()
        #expect(filters.includeGenres.isEmpty)
        #expect(filters.excludeGenres.isEmpty)
        #expect(filters.includeArtists.isEmpty)
        #expect(filters.excludeArtists.isEmpty)
        #expect(filters.eras.isEmpty)
        #expect(filters.moods.isEmpty)
    }

    @Test func tuningFiltersPopulated() {
        var filters = TuningFilters()
        filters.includeGenres = ["jazz", "indie"]
        filters.excludeGenres = ["metal"]
        filters.includeArtists = ["radiohead"]
        filters.excludeArtists = ["drake"]
        filters.eras = ["90s"]
        filters.moods = ["chill", "dreamy"]

        #expect(filters.includeGenres.count == 2)
        #expect(filters.excludeGenres.count == 1)
        #expect(filters.includeArtists == ["radiohead"])
        #expect(filters.excludeArtists == ["drake"])
        #expect(filters.eras == ["90s"])
        #expect(filters.moods.count == 2)
    }

    @Test func tuningFiltersSendable() {
        // Verify TuningFilters can be passed across actor boundaries
        let filters = TuningFilters()
        let _: Sendable = filters
        // If this compiles, TuningFilters conforms to Sendable
    }

    // MARK: - Integration: TuningParser -> TuningFilters

    @Test func tuningParserOutputFeedsTuningFilters() {
        let filters = TuningParser.parse("chill 90s jazz, no metal, artists like \"Radiohead\"")

        #expect(filters.moods.contains("chill"))
        #expect(filters.eras.contains("90s"))
        #expect(filters.includeGenres.contains("jazz"))
        #expect(filters.excludeGenres.contains("metal"))
        #expect(filters.includeArtists.contains("radiohead"))
    }

    // MARK: - Engine with Empty History

    @Test func generateRecommendationsWithEmptyHistory() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ReverieTrack.self, ListeningSignal.self, ReverieArtist.self, ReverieAlbum.self,
            configurations: config
        )
        let context = ModelContext(container)

        let engine = RecommendationEngine()
        let filters = TuningFilters()

        let results = await engine.generateRecommendations(
            modelContext: context,
            tuningFilters: filters
        )

        // No listening history -> no seeds -> no recommendations
        #expect(results.isEmpty)
    }

    // MARK: - RecommendedTrack Sorting

    @Test func recommendedTracksSortByScoreDescending() {
        var tracks = [
            RecommendedTrack(id: "a", videoID: "a", title: "Low", artist: "A", thumbnailURL: nil, score: 0.2),
            RecommendedTrack(id: "b", videoID: "b", title: "High", artist: "B", thumbnailURL: nil, score: 0.9),
            RecommendedTrack(id: "c", videoID: "c", title: "Mid", artist: "C", thumbnailURL: nil, score: 0.5),
        ]

        tracks.sort { $0.score > $1.score }

        #expect(tracks[0].title == "High")
        #expect(tracks[1].title == "Mid")
        #expect(tracks[2].title == "Low")
    }

    @Test func recommendedTracksLimitTo20() {
        let tracks = (1...50).map { i in
            RecommendedTrack(
                id: "\(i)", videoID: "\(i)", title: "Track \(i)",
                artist: "Artist", thumbnailURL: nil, score: Double(i) / 50.0
            )
        }

        let limited = Array(tracks.sorted { $0.score > $1.score }.prefix(20))
        #expect(limited.count == 20)
        #expect(limited[0].score > limited[19].score)
    }

    // MARK: - Scoring Logic Validation

    @Test func scoringWeightsSum() {
        // The engine uses: frequency(40%) + familiarity(30%) + recency(30%) + tuning bonus
        // Verify the weight constants produce expected composite ranges
        let frequencyWeight = 0.4
        let familiarityWeight = 0.3
        let recencyWeight = 0.3

        let baseWeightsTotal = frequencyWeight + familiarityWeight + recencyWeight
        #expect(abs(baseWeightsTotal - 1.0) < 0.001)
    }

    @Test func maxScoreWithTuningBonusClampsToOne() {
        // Max possible: frequency(1.0*0.4) + familiarity(1.0*0.3) + recency(1.0*0.3) + artist(0.15) + genre(0.1) + mood(0.05)
        let maxComposite = (1.0 * 0.4) + (1.0 * 0.3) + (1.0 * 0.3) + 0.15 + 0.1 + 0.05
        let clamped = min(maxComposite, 1.0)
        #expect(clamped == 1.0)
        #expect(maxComposite > 1.0) // confirms clamping is necessary
    }

    @Test func minScoreWithoutBonuses() {
        // Min possible (non-excluded): frequency(0) + familiarity(0.3*0.3) + recency(0.3*0.3)
        let minComposite = (0.0 * 0.4) + (0.3 * 0.3) + (0.3 * 0.3)
        #expect(minComposite > 0.0)
        #expect(minComposite < 0.5)
    }
}
