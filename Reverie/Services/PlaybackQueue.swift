//
//  PlaybackQueue.swift
//  Reverie
//
//  Manages playback queue with shuffle, repeat, and persistence
//

import Foundation
import SwiftData

/// Manages the playback queue separately from the audio engine
@MainActor
@Observable
class PlaybackQueue {
    
    // MARK: - Queue State
    
    var tracks: [ReverieTrack] = []
    var currentIndex: Int = 0
    var shuffleEnabled: Bool = false {
        didSet {
            if shuffleEnabled != oldValue {
                handleShuffleToggle()
            }
        }
    }
    var repeatMode: RepeatMode = .off {
        didSet {
            persistState()
        }
    }
    
    private var originalOrder: [ReverieTrack] = []  // Tracks before shuffle
    
    enum RepeatMode: String, Codable {
        case off
        case all
        case one
    }
    
    // MARK: - Computed Properties
    
    var currentTrack: ReverieTrack? {
        guard currentIndex >= 0 && currentIndex < tracks.count else {
            return nil
        }
        return tracks[currentIndex]
    }
    
    var hasNext: Bool {
        switch repeatMode {
        case .off:
            return currentIndex < tracks.count - 1
        case .all, .one:
            return !tracks.isEmpty
        }
    }
    
    var hasPrevious: Bool {
        switch repeatMode {
        case .off:
            return currentIndex > 0
        case .all, .one:
            return !tracks.isEmpty
        }
    }
    
    var isEmpty: Bool {
        return tracks.isEmpty
    }
    
    var count: Int {
        return tracks.count
    }
    
    // MARK: - Queue Management
    
    /// Sets a new queue and starts playing from the specified index
    func setQueue(_ newTracks: [ReverieTrack], startingAt index: Int = 0) {
        guard !newTracks.isEmpty else {
            clear()
            return
        }
        
        tracks = newTracks
        originalOrder = newTracks
        currentIndex = max(0, min(index, newTracks.count - 1))
        
        if shuffleEnabled {
            applyShufflePreservingCurrent()
        }
        
        persistState()
    }
    
    /// Adds a track to the end of the queue
    func append(_ track: ReverieTrack) {
        tracks.append(track)
        originalOrder.append(track)
        persistState()
    }
    
    /// Inserts a track after the current track (up next)
    func playNext(_ track: ReverieTrack) {
        let insertIndex = currentIndex + 1
        tracks.insert(track, at: insertIndex)
        originalOrder.insert(track, at: insertIndex)
        persistState()
    }
    
    /// Removes a track from the queue
    func remove(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        
        let trackToRemove = tracks[index]
        tracks.remove(at: index)
        
        if let originalIndex = originalOrder.firstIndex(where: { $0.id == trackToRemove.id }) {
            originalOrder.remove(at: originalIndex)
        }
        
        // Adjust current index if necessary
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex && currentIndex >= tracks.count {
            currentIndex = tracks.count - 1
        }
        
        persistState()
    }
    
    /// Moves a track from one position to another
    func move(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < tracks.count,
              destinationIndex >= 0 && destinationIndex < tracks.count else {
            return
        }
        
        let track = tracks.remove(at: sourceIndex)
        tracks.insert(track, at: destinationIndex)
        
        // Update current index if it was affected
        if sourceIndex == currentIndex {
            currentIndex = destinationIndex
        } else if sourceIndex < currentIndex && destinationIndex >= currentIndex {
            currentIndex -= 1
        } else if sourceIndex > currentIndex && destinationIndex <= currentIndex {
            currentIndex += 1
        }
        
        persistState()
    }
    
    /// Clears the queue
    func clear() {
        tracks = []
        originalOrder = []
        currentIndex = 0
        persistState()
    }
    
    // MARK: - Navigation
    
    /// Advances to the next track in the queue
    func next() -> ReverieTrack? {
        guard !tracks.isEmpty else { return nil }
        
        switch repeatMode {
        case .one:
            // Repeat current track
            return currentTrack
            
        case .all:
            // Loop to beginning if at end
            currentIndex = (currentIndex + 1) % tracks.count
            persistState()
            return currentTrack
            
        case .off:
            // Stop if at end
            guard currentIndex < tracks.count - 1 else {
                return nil
            }
            currentIndex += 1
            persistState()
            return currentTrack
        }
    }
    
    /// Goes back to the previous track in the queue
    func previous() -> ReverieTrack? {
        guard !tracks.isEmpty else { return nil }
        
        switch repeatMode {
        case .one:
            // Repeat current track
            return currentTrack
            
        case .all:
            // Loop to end if at beginning
            currentIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
            persistState()
            return currentTrack
            
        case .off:
            // Stop if at beginning
            guard currentIndex > 0 else {
                return nil
            }
            currentIndex -= 1
            persistState()
            return currentTrack
        }
    }
    
    /// Jumps to a specific index in the queue
    func jumpTo(index: Int) -> ReverieTrack? {
        guard index >= 0 && index < tracks.count else {
            return nil
        }
        currentIndex = index
        persistState()
        return currentTrack
    }
    
    // MARK: - Shuffle Logic
    
    private func handleShuffleToggle() {
        if shuffleEnabled {
            applyShufflePreservingCurrent()
        } else {
            restoreOriginalOrder()
        }
        persistState()
    }
    
    private func applyShufflePreservingCurrent() {
        guard let current = currentTrack else { return }
        
        // Shuffle all tracks except the current one
        var remaining = tracks.filter { $0.id != current.id }
        remaining.shuffle()
        
        // Rebuild queue with current track first, then shuffled tracks
        tracks = [current] + remaining
        currentIndex = 0
    }
    
    private func restoreOriginalOrder() {
        guard let current = currentTrack else {
            tracks = originalOrder
            currentIndex = 0
            return
        }
        
        // Find the current track in original order
        if let originalIndex = originalOrder.firstIndex(where: { $0.id == current.id }) {
            tracks = originalOrder
            currentIndex = originalIndex
        } else {
            tracks = originalOrder
            currentIndex = 0
        }
    }
    
    // MARK: - Persistence
    
    private struct QueueState: Codable {
        let trackIDs: [UUID]
        let currentIndex: Int
        let shuffleEnabled: Bool
        let repeatMode: RepeatMode
    }
    
    private let queueStateKey = "com.reverie.playbackQueue.state"
    
    /// Persists the current queue state to UserDefaults
    private func persistState() {
        let state = QueueState(
            trackIDs: tracks.map { $0.id },
            currentIndex: currentIndex,
            shuffleEnabled: shuffleEnabled,
            repeatMode: repeatMode
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: queueStateKey)
        }
    }
    
    /// Restores the queue state from UserDefaults
    func restoreState(modelContext: ModelContext) throws {
        guard let data = UserDefaults.standard.data(forKey: queueStateKey),
              let state = try? JSONDecoder().decode(QueueState.self, from: data) else {
            return
        }
        
        // Fetch tracks from SwiftData
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate { track in
                state.trackIDs.contains(track.id)
            }
        )
        
        let fetchedTracks = try modelContext.fetch(descriptor)
        
        // Reorder fetched tracks to match the saved order
        var orderedTracks: [ReverieTrack] = []
        for id in state.trackIDs {
            if let track = fetchedTracks.first(where: { $0.id == id }) {
                orderedTracks.append(track)
            }
        }
        
        guard !orderedTracks.isEmpty else { return }
        
        tracks = orderedTracks
        originalOrder = orderedTracks
        currentIndex = min(state.currentIndex, orderedTracks.count - 1)
        shuffleEnabled = state.shuffleEnabled
        repeatMode = state.repeatMode
    }
    
    /// Clears persisted queue state
    func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: queueStateKey)
    }
}
