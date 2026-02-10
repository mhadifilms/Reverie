//
//  AudioPlayer.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import AVFoundation
import MediaPlayer
import Accelerate
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
    var waveformLevels: [Float] = Array(
        repeating: Constants.waveformMinLevel,
        count: Constants.waveformBarCount
    )
    var volume: Float = 1.0 {
        didSet {
            audioPlayerNode.volume = volume
        }
    }
    
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var isTapInstalled = false
    private var lastWaveformUpdate: TimeInterval = 0
    
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
        installMeterTapIfNeeded()
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
        
        // Toggle Play/Pause (media keys)
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
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
        resetWaveform()
        
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
            audioPlayerNode.volume = volume
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
        resetWaveform()
        
        // Update Now Playing
        updateNowPlayingInfo()
        
        // Haptic feedback
        HapticManager.shared.playPause()
    }
    
    func stop() {
        audioPlayerNode.stop()
        isPlaying = false
        currentTime = 0
        resetWaveform()
        
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
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                guard self.isPlaying else {
                    timer.invalidate()
                    return
                }
                
                if let nodeTime = self.audioPlayerNode.lastRenderTime,
                   let playerTime = self.audioPlayerNode.playerTime(forNodeTime: nodeTime) {
                    self.currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    // MARK: - Waveform Metering
    
    private func installMeterTapIfNeeded() {
        guard !isTapInstalled else { return }
        let format = audioPlayerNode.outputFormat(forBus: 0)
        
        audioPlayerNode.installTap(
            onBus: 0,
            bufferSize: Constants.waveformTapBufferSize,
            format: format
        ) { [weak self] buffer, _ in
            guard let self = self else { return }
            let levels = self.computeWaveformLevels(from: buffer)
            
            Task { @MainActor in
                if self.isPlaying {
                    self.pushWaveformLevels(levels)
                } else {
                    self.resetWaveform()
                }
            }
        }
        
        isTapInstalled = true
    }
    
    private func computeWaveformLevels(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return Array(repeating: Constants.waveformMinLevel, count: Constants.waveformBarCount)
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 {
            return Array(repeating: Constants.waveformMinLevel, count: Constants.waveformBarCount)
        }
        
        let barCount = Constants.waveformBarCount
        let samplesPerBar = max(frameLength / barCount, 1)
        var levels = Array(repeating: Constants.waveformMinLevel, count: barCount)
        
        for bar in 0..<barCount {
            let start = bar * samplesPerBar
            if start >= frameLength { break }
            
            let count = min(samplesPerBar, frameLength - start)
            var accumulatedPeak: Float = 0
            
            for channel in 0..<channelCount {
                var peak: Float = 0
                vDSP_maxmgv(
                    channelData[channel].advanced(by: start),
                    1,
                    &peak,
                    vDSP_Length(count)
                )
                accumulatedPeak += peak
            }
            
            let averagePeak = accumulatedPeak / Float(channelCount)
            let shaped = sqrtf(max(averagePeak, 0))
            levels[bar] = max(Constants.waveformMinLevel, min(shaped, 1.0))
        }
        
        return levels
    }
    
    @MainActor
    private func pushWaveformLevels(_ newLevels: [Float]) {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastWaveformUpdate >= Constants.waveformUpdateInterval else { return }
        lastWaveformUpdate = now
        
        if newLevels.count != waveformLevels.count {
            waveformLevels = newLevels
            return
        }
        
        for index in waveformLevels.indices {
            let current = waveformLevels[index]
            let target = max(Constants.waveformMinLevel, min(newLevels[index], 1.0))
            let smoothing = target > current
                ? Constants.waveformAttackSmoothing
                : Constants.waveformDecaySmoothing
            waveformLevels[index] = current + (target - current) * smoothing
        }
    }
    
    @MainActor
    private func resetWaveform() {
        waveformLevels = Array(
            repeating: Constants.waveformMinLevel,
            count: Constants.waveformBarCount
        )
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
