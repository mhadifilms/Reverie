//
//  SignalCollectorTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for SignalCollector
//  Uses in-memory SwiftData container to verify signal recording.
//

import Testing
import Foundation
import SwiftData
@testable import Reverie

@MainActor
struct SignalCollectorTests {

    // MARK: - Helpers

    /// Creates an in-memory ModelContainer and ModelContext for testing.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ReverieTrack.self, ListeningSignal.self, ReverieArtist.self, ReverieAlbum.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeTrack(title: String = "Test Track", artist: String = "Test Artist") -> ReverieTrack {
        ReverieTrack(
            title: title,
            artist: artist,
            videoID: UUID().uuidString,
            thumbnailURL: nil
        )
    }

    private func fetchSignals(from context: ModelContext) throws -> [ListeningSignal] {
        let descriptor = FetchDescriptor<ListeningSignal>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - recordPlay

    @Test func recordPlayCreatesPlaySignal() throws {
        let context = try makeContext()
        let track = makeTrack()
        context.insert(track)

        let collector = SignalCollector()
        collector.recordPlay(track: track, duration: 45.0, wasFullPlay: false, modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 1)
        #expect(signals[0].signalType == "play")
        #expect(signals[0].trackID == track.id)
        #expect(signals[0].artistName == "Test Artist")
        #expect(signals[0].durationListened == 45.0)
        #expect(signals[0].isFullPlay == false)
    }

    @Test func recordFullPlayCreatesCompleteSignal() throws {
        let context = try makeContext()
        let track = makeTrack()
        context.insert(track)

        let collector = SignalCollector()
        collector.recordPlay(track: track, duration: 210.0, wasFullPlay: true, modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 1)
        #expect(signals[0].signalType == "complete")
        #expect(signals[0].isFullPlay == true)
        #expect(signals[0].durationListened == 210.0)
    }

    // MARK: - recordSkip

    @Test func recordSkipCreatesSkipSignal() throws {
        let context = try makeContext()
        let track = makeTrack()
        context.insert(track)

        let collector = SignalCollector()
        collector.recordSkip(track: track, afterSeconds: 12.5, modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 1)
        #expect(signals[0].signalType == "skip")
        #expect(signals[0].trackID == track.id)
        #expect(signals[0].durationListened == 12.5)
        #expect(signals[0].isFullPlay == false)
    }

    @Test func recordSkipPreservesArtistName() throws {
        let context = try makeContext()
        let track = makeTrack(artist: "Daft Punk")
        context.insert(track)

        let collector = SignalCollector()
        collector.recordSkip(track: track, afterSeconds: 5.0, modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals[0].artistName == "Daft Punk")
    }

    // MARK: - recordSearch

    @Test func recordSearchCreatesSearchSignal() throws {
        let context = try makeContext()

        let collector = SignalCollector()
        collector.recordSearch(query: "chill vibes", modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 1)
        #expect(signals[0].signalType == "search")
        #expect(signals[0].query == "chill vibes")
        #expect(signals[0].trackID == nil)
    }

    @Test func recordSearchTrimsWhitespace() throws {
        let context = try makeContext()

        let collector = SignalCollector()
        collector.recordSearch(query: "  padded query  \n", modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 1)
        #expect(signals[0].query == "padded query")
    }

    @Test func recordSearchIgnoresEmptyQuery() throws {
        let context = try makeContext()

        let collector = SignalCollector()
        collector.recordSearch(query: "", modelContext: context)
        collector.recordSearch(query: "   ", modelContext: context)
        collector.recordSearch(query: "\n\t", modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.isEmpty)
    }

    // MARK: - recordDownload

    @Test func recordDownloadCreatesDownloadSignal() throws {
        let context = try makeContext()
        let track = makeTrack(title: "Downloaded Song")
        context.insert(track)

        let collector = SignalCollector()
        collector.recordDownload(track: track, modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 1)
        #expect(signals[0].signalType == "download")
        #expect(signals[0].trackID == track.id)
        #expect(signals[0].isFullPlay == false)
    }

    // MARK: - Multiple Signals

    @Test func multipleSignalsAccumulate() throws {
        let context = try makeContext()
        let track = makeTrack()
        context.insert(track)

        let collector = SignalCollector()
        collector.recordPlay(track: track, duration: 30.0, wasFullPlay: false, modelContext: context)
        collector.recordSkip(track: track, afterSeconds: 10.0, modelContext: context)
        collector.recordDownload(track: track, modelContext: context)
        collector.recordSearch(query: "test", modelContext: context)

        let signals = try fetchSignals(from: context)
        #expect(signals.count == 4)

        let types = Set(signals.map(\.signalType))
        #expect(types.contains("play"))
        #expect(types.contains("skip"))
        #expect(types.contains("download"))
        #expect(types.contains("search"))
    }

    // MARK: - Timestamp

    @Test func signalTimestampIsRecent() throws {
        let context = try makeContext()
        let track = makeTrack()
        context.insert(track)

        let before = Date()
        let collector = SignalCollector()
        collector.recordPlay(track: track, duration: 60.0, wasFullPlay: true, modelContext: context)
        let after = Date()

        let signals = try fetchSignals(from: context)
        #expect(signals[0].timestamp >= before)
        #expect(signals[0].timestamp <= after)
    }
}
