//
//  PlaybackQueueTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for PlaybackQueue
//

import Testing
import Foundation
@testable import Reverie

@MainActor
struct PlaybackQueueTests {

    // MARK: - Helpers

    /// Creates a minimal ReverieTrack for testing.
    private func makeTrack(title: String = "Track", videoID: String? = nil) -> ReverieTrack {
        ReverieTrack(
            title: title,
            artist: "Artist",
            videoID: videoID ?? UUID().uuidString,
            thumbnailURL: nil
        )
    }

    private func makeQueue(count: Int) -> ([ReverieTrack], PlaybackQueue) {
        let tracks = (1...count).map { makeTrack(title: "Track \($0)") }
        let queue = PlaybackQueue()
        queue.setQueue(tracks)
        return (tracks, queue)
    }

    // MARK: - Set Queue

    @Test func setQueuePopulatesTracksAndIndex() {
        let (tracks, queue) = makeQueue(count: 3)
        #expect(queue.count == 3)
        #expect(queue.currentIndex == 0)
        #expect(queue.currentTrack?.id == tracks[0].id)
    }

    @Test func setQueueWithStartingIndex() {
        let tracks = (1...5).map { makeTrack(title: "T\($0)") }
        let queue = PlaybackQueue()
        queue.setQueue(tracks, startingAt: 2)
        #expect(queue.currentIndex == 2)
        #expect(queue.currentTrack?.id == tracks[2].id)
    }

    @Test func setQueueClampsIndex() {
        let tracks = [makeTrack()]
        let queue = PlaybackQueue()
        queue.setQueue(tracks, startingAt: 100)
        #expect(queue.currentIndex == 0) // clamped to count - 1
    }

    @Test func setQueueWithEmptyClears() {
        let (_, queue) = makeQueue(count: 3)
        queue.setQueue([])
        #expect(queue.isEmpty)
        #expect(queue.count == 0)
    }

    // MARK: - Navigation: Next

    @Test func nextAdvancesIndex() {
        let (tracks, queue) = makeQueue(count: 3)
        let next = queue.next()
        #expect(next?.id == tracks[1].id)
        #expect(queue.currentIndex == 1)
    }

    @Test func nextReturnsNilAtEndWithRepeatOff() {
        let (_, queue) = makeQueue(count: 2)
        _ = queue.next() // index 1
        let result = queue.next() // at end
        #expect(result == nil)
    }

    @Test func nextWrapsWithRepeatAll() {
        let (tracks, queue) = makeQueue(count: 2)
        queue.repeatMode = .all
        _ = queue.next() // index 1
        let result = queue.next() // wraps to 0
        #expect(result?.id == tracks[0].id)
        #expect(queue.currentIndex == 0)
    }

    @Test func nextReturnsCurrentWithRepeatOne() {
        let (tracks, queue) = makeQueue(count: 3)
        queue.repeatMode = .one
        let result = queue.next()
        #expect(result?.id == tracks[0].id) // stays on same track
        #expect(queue.currentIndex == 0)
    }

    @Test func nextOnEmptyReturnsNil() {
        let queue = PlaybackQueue()
        #expect(queue.next() == nil)
    }

    // MARK: - Navigation: Previous

    @Test func previousGoesBack() {
        let (tracks, queue) = makeQueue(count: 3)
        _ = queue.next() // index 1
        let prev = queue.previous()
        #expect(prev?.id == tracks[0].id)
        #expect(queue.currentIndex == 0)
    }

    @Test func previousReturnsNilAtStartWithRepeatOff() {
        let (_, queue) = makeQueue(count: 3)
        let result = queue.previous()
        #expect(result == nil)
    }

    @Test func previousWrapsWithRepeatAll() {
        let (tracks, queue) = makeQueue(count: 3)
        queue.repeatMode = .all
        let result = queue.previous() // wraps to last
        #expect(result?.id == tracks[2].id)
        #expect(queue.currentIndex == 2)
    }

    @Test func previousReturnsCurrentWithRepeatOne() {
        let (tracks, queue) = makeQueue(count: 3)
        _ = queue.next() // index 1
        queue.repeatMode = .one
        let result = queue.previous()
        #expect(result?.id == tracks[1].id)
    }

    // MARK: - Jump To

    @Test func jumpToValidIndex() {
        let (tracks, queue) = makeQueue(count: 5)
        let result = queue.jumpTo(index: 3)
        #expect(result?.id == tracks[3].id)
        #expect(queue.currentIndex == 3)
    }

    @Test func jumpToInvalidIndexReturnsNil() {
        let (_, queue) = makeQueue(count: 3)
        #expect(queue.jumpTo(index: -1) == nil)
        #expect(queue.jumpTo(index: 5) == nil)
    }

    // MARK: - Append

    @Test func appendAddsToEnd() {
        let (_, queue) = makeQueue(count: 2)
        let newTrack = makeTrack(title: "Appended")
        queue.append(newTrack)
        #expect(queue.count == 3)
        #expect(queue.tracks.last?.id == newTrack.id)
    }

    // MARK: - Play Next

    @Test func playNextInsertsAfterCurrent() {
        let (tracks, queue) = makeQueue(count: 3)
        let newTrack = makeTrack(title: "Up Next")
        queue.playNext(newTrack)
        #expect(queue.count == 4)
        #expect(queue.tracks[1].id == newTrack.id)
        #expect(queue.currentTrack?.id == tracks[0].id)
    }

    // MARK: - Remove

    @Test func removeTrackBeforeCurrent() {
        let (tracks, queue) = makeQueue(count: 4)
        _ = queue.jumpTo(index: 2)
        queue.remove(at: 0)
        #expect(queue.count == 3)
        // Current index should shift down by 1
        #expect(queue.currentIndex == 1)
        #expect(queue.currentTrack?.id == tracks[2].id)
    }

    @Test func removeTrackAfterCurrent() {
        let (tracks, queue) = makeQueue(count: 4)
        queue.remove(at: 3)
        #expect(queue.count == 3)
        #expect(queue.currentIndex == 0)
        #expect(queue.currentTrack?.id == tracks[0].id)
    }

    @Test func removeCurrentTrackAtEnd() {
        let (_, queue) = makeQueue(count: 3)
        _ = queue.jumpTo(index: 2)
        queue.remove(at: 2)
        #expect(queue.count == 2)
        // Current index clamps to count - 1
        #expect(queue.currentIndex == 1)
    }

    @Test func removeOutOfBoundsIsNoOp() {
        let (_, queue) = makeQueue(count: 2)
        queue.remove(at: -1)
        queue.remove(at: 5)
        #expect(queue.count == 2)
    }

    // MARK: - Move

    @Test func moveTrackForward() {
        let (tracks, queue) = makeQueue(count: 4)
        // Move track at 0 (current) to position 2
        queue.move(from: 0, to: 2)
        #expect(queue.currentIndex == 2)
        #expect(queue.currentTrack?.id == tracks[0].id)
    }

    @Test func moveTrackBackward() {
        let (tracks, queue) = makeQueue(count: 4)
        _ = queue.jumpTo(index: 0)
        queue.move(from: 3, to: 0)
        // Current was at 0, source > current, destination <= current
        #expect(queue.currentIndex == 1)
        #expect(queue.tracks[0].id == tracks[3].id)
    }

    @Test func moveOutOfBoundsIsNoOp() {
        let (_, queue) = makeQueue(count: 3)
        queue.move(from: -1, to: 2)
        queue.move(from: 0, to: 10)
        #expect(queue.count == 3)
    }

    // MARK: - Clear

    @Test func clearResetsQueue() {
        let (_, queue) = makeQueue(count: 5)
        queue.clear()
        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.currentIndex == 0)
        #expect(queue.currentTrack == nil)
    }

    // MARK: - Has Next / Has Previous

    @Test func hasNextAndHasPreviousRepeatOff() {
        let (_, queue) = makeQueue(count: 3)
        // At index 0
        #expect(queue.hasNext)
        #expect(!queue.hasPrevious)
        _ = queue.jumpTo(index: 1)
        #expect(queue.hasNext)
        #expect(queue.hasPrevious)
        _ = queue.jumpTo(index: 2)
        #expect(!queue.hasNext)
        #expect(queue.hasPrevious)
    }

    @Test func hasNextAndHasPreviousRepeatAll() {
        let (_, queue) = makeQueue(count: 2)
        queue.repeatMode = .all
        // Always true when non-empty
        #expect(queue.hasNext)
        #expect(queue.hasPrevious)
    }

    @Test func hasNextOnEmpty() {
        let queue = PlaybackQueue()
        queue.repeatMode = .all
        #expect(!queue.hasNext)
        #expect(!queue.hasPrevious)
    }

    // MARK: - Shuffle

    @Test func shufflePreservesCurrent() {
        let (tracks, queue) = makeQueue(count: 10)
        _ = queue.jumpTo(index: 3)
        let currentBefore = queue.currentTrack?.id
        queue.shuffleEnabled = true
        #expect(queue.currentIndex == 0) // current moves to front
        #expect(queue.currentTrack?.id == currentBefore)
        #expect(queue.count == 10)
        // First track should be the one that was current
        #expect(queue.tracks[0].id == tracks[3].id)
    }

    @Test func disableShuffleRestoresOrder() {
        let (tracks, queue) = makeQueue(count: 5)
        _ = queue.jumpTo(index: 2)
        queue.shuffleEnabled = true
        let currentID = queue.currentTrack?.id
        queue.shuffleEnabled = false
        // Should restore original order
        #expect(queue.currentTrack?.id == currentID)
        // Original order should be restored
        for i in 0..<tracks.count {
            #expect(queue.tracks[i].id == tracks[i].id)
        }
    }

    // MARK: - Repeat Mode

    @Test func repeatModeCycles() {
        let queue = PlaybackQueue()
        #expect(queue.repeatMode == .off)
        queue.repeatMode = .all
        #expect(queue.repeatMode == .all)
        queue.repeatMode = .one
        #expect(queue.repeatMode == .one)
        queue.repeatMode = .off
        #expect(queue.repeatMode == .off)
    }
}
