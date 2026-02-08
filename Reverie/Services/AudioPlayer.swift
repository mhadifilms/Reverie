//
//  AudioPlayer.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import AVFoundation
import MediaPlayer
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Manages audio playback with AVAudioEngine and system integration
@MainActor
@Observable
class AudioPlayer {
    
    // Playback state
    var isPlaying: Bool = false
    var currentTrack: ReverieTrack?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var queue: [ReverieTrack] = []
    var currentIndex: Int = 0
    
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    
    // Background audio session
    private let storageManager = StorageManager()
    
    init() {
        setupAudioSession()
        setupAudioEngine()
        setupRemoteControls()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }
    
    private func setupAudioEngine() {
        // Attach player node
        audioEngine.attach(audioPlayerNode)
        
        // Connect player node to main mixer
        audioEngine.connect(
            audioPlayerNode,
            to: audioEngine.mainMixerNode,
            format: nil
        )
        
        // Prepare engine
        audioEngine.prepare()
    }
    
    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipToNext()
            }
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipToPrevious()
            }
            return .success
        }
        
        // Change playback position
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor in
                    self?.seek(to: event.positionTime)
                }
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Playback Control
    
    func loadTrack(_ track: ReverieTrack) async throws {
        // Stop current playback
        stop()
        
        // Get file URL
        guard let relativePath = track.localFilePath else {
            throw PlayerError.trackNotDownloaded
        }
        
        let fileURL = try await storageManager.getAudioFileURL(relativePath: relativePath)
        
        // Load audio file
        audioFile = try AVAudioFile(forReading: fileURL)
        
        guard let audioFile = audioFile else {
            throw PlayerError.fileLoadFailed
        }
        
        // Update state
        currentTrack = track
        duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        currentTime = 0
        
        // Update Now Playing info
        updateNowPlayingInfo()
        
        // Schedule file for playback
        audioPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
    }
    
    func play() {
        guard currentTrack != nil, audioFile != nil else { return }
        
        do {
            // Start engine if needed
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            // Play
            audioPlayerNode.play()
            isPlaying = true
            
            // Update Now Playing
            updateNowPlayingInfo()
            
            // Haptic feedback
            HapticManager.shared.playPause()
            
            // Start time updates
            startTimeUpdates()
            
        } catch {
            print("Failed to start playback: \(error)")
        }
    }
    
    func pause() {
        audioPlayerNode.pause()
        isPlaying = false
        
        // Update Now Playing
        updateNowPlayingInfo()
        
        // Haptic feedback
        HapticManager.shared.playPause()
    }
    
    func stop() {
        audioPlayerNode.stop()
        isPlaying = false
        currentTime = 0
        
        // Reset playback
        if let audioFile = audioFile {
            audioPlayerNode.scheduleFile(audioFile, at: nil)
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        let sampleRate = audioFile.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        
        // Stop current playback
        audioPlayerNode.stop()
        
        // Schedule from new position
        audioPlayerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(audioFile.length - startFrame),
            at: nil
        )
        
        // Resume playback if was playing
        if isPlaying {
            audioPlayerNode.play()
        }
        
        currentTime = time
        updateNowPlayingInfo()
    }
    
    // MARK: - Queue Management
    
    func setQueue(_ tracks: [ReverieTrack], startingAt index: Int = 0) {
        queue = tracks
        currentIndex = index
        
        if index < tracks.count {
            Task {
                try? await loadTrack(tracks[index])
            }
        }
    }
    
    func skipToNext() {
        guard currentIndex < queue.count - 1 else { return }
        
        currentIndex += 1
        Task {
            try? await loadTrack(queue[currentIndex])
            play()
        }
        
        HapticManager.shared.skip()
    }
    
    func skipToPrevious() {
        // If more than 3 seconds into track, restart it
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        // Otherwise, go to previous track
        guard currentIndex > 0 else { return }
        
        currentIndex -= 1
        Task {
            try? await loadTrack(queue[currentIndex])
            play()
        }
        
        HapticManager.shared.skip()
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Album art
        #if os(iOS)
        if let artData = track.albumArtData,
           let image = UIImage(data: artData) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size
            ) { _ in image }
        }
        #elseif os(macOS)
        if let artData = track.albumArtData,
           let image = NSImage(data: artData) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size
            ) { _ in image }
        }
        #endif
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Time Updates
    
    private func startTimeUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                if let nodeTime = self.audioPlayerNode.lastRenderTime,
                   let playerTime = self.audioPlayerNode.playerTime(forNodeTime: nodeTime) {
                    self.currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    // MARK: - Errors
    
    enum PlayerError: LocalizedError {
        case trackNotDownloaded
        case fileLoadFailed
        case playbackFailed
        
        var errorDescription: String? {
            switch self {
            case .trackNotDownloaded:
                return "Track has not been downloaded"
            case .fileLoadFailed:
                return "Failed to load audio file"
            case .playbackFailed:
                return "Playback failed"
            }
        }
    }
}
