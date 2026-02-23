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
import WidgetKit
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
    var waveformLevels: [Float] = Array(
        repeating: Constants.waveformMinLevel,
        count: Constants.waveformBarCount
    )
    var volume: Float = 1.0 {
        didSet {
            audioPlayerNode.volume = volume
        }
    }
    
    // Playback queue (separate service)
    let playbackQueue = PlaybackQueue()
    
    // Handoff support
    var userActivity: NSUserActivity?
    
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var isTapInstalled = false
    private var lastWaveformUpdate: TimeInterval = 0
    
    // Timer management (FIXED: single timer reference)
    private var timeUpdateTimer: Timer?
    private var endOfTrackTimer: Timer?
    
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
        // Stop current playback and invalidate timers
        stop()
        
        // Get file URL
        guard let relativePath = track.localFilePath else {
            let error = ReverieError.playback(.trackNotDownloaded(trackTitle: track.title))
            ErrorBannerState.shared.post(error)
            throw error
        }
        
        do {
            let fileURL = try await storageManager.getAudioFileURL(relativePath: relativePath)
            
            // Load audio file
            audioFile = try AVAudioFile(forReading: fileURL)
            
            guard let audioFile = audioFile else {
                throw ReverieError.playback(.fileLoadFailed(
                    NSError(domain: "AudioPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAudioFile is nil"])
                ))
            }
            
            // Update state
            currentTrack = track
            duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            currentTime = 0
            resetWaveform()
            
            // Update Now Playing info
            updateNowPlayingInfo()
            
            // Schedule file for playback WITH completion handler
            audioPlayerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleTrackCompletion()
                }
            }
            
        } catch let error as ReverieError {
            ErrorBannerState.shared.post(error)
            throw error
        } catch {
            let reverieError = ReverieError.playback(.fileLoadFailed(error))
            ErrorBannerState.shared.post(reverieError)
            throw reverieError
        }
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
            
            // Start time updates (FIXED: invalidates previous timer)
            startTimeUpdates()
            
            // Start end-of-track polling
            startEndOfTrackPolling()
            
        } catch {
            let error = ReverieError.playback(.audioEngineFailed(error))
            ErrorBannerState.shared.post(error)
        }
    }
    
    func pause() {
        audioPlayerNode.pause()
        isPlaying = false
        resetWaveform()
        
        // Invalidate timers
        stopTimers()
        
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
        
        // Invalidate timers
        stopTimers()
        
        // Reset playback
        if let audioFile = audioFile {
            audioPlayerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleTrackCompletion()
                }
            }
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
    
    // MARK: - Queue Management (delegated to PlaybackQueue)
    
    func setQueue(_ tracks: [ReverieTrack], startingAt index: Int = 0) {
        playbackQueue.setQueue(tracks, startingAt: index)
        
        if let track = playbackQueue.currentTrack {
            Task {
                try? await loadTrack(track)
            }
        }
    }
    
    func skipToNext() {
        guard let nextTrack = playbackQueue.next() else {
            // No more tracks, stop playback
            stop()
            return
        }
        
        Task {
            do {
                try await loadTrack(nextTrack)
                play()
                HapticManager.shared.skip()
            } catch {
                // Error already posted by loadTrack
            }
        }
    }
    
    func skipToPrevious() {
        // If more than 3 seconds into track, restart it
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        // Otherwise, go to previous track
        guard let previousTrack = playbackQueue.previous() else {
            // No previous track, restart current
            seek(to: 0)
            return
        }
        
        Task {
            do {
                try await loadTrack(previousTrack)
                play()
                HapticManager.shared.skip()
            } catch {
                // Error already posted by loadTrack
            }
        }
    }
    
    /// Called when a track finishes playing naturally
    private func handleTrackCompletion() {
        guard isPlaying else { return }
        
        // Auto-advance to next track
        skipToNext()
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
        
        // Update Handoff user activity
        updateUserActivity()
    }
    
    private func updateUserActivity() {
        guard let track = currentTrack else {
            userActivity?.invalidate()
            userActivity = nil
            updateWidgetData(track: nil)
            return
        }
        
        let activity = NSUserActivity(activityType: "com.reverie.playback")
        activity.title = "Playing \(track.title)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif
        
        var userInfo: [String: Any] = [
            "trackID": track.id.uuidString,
            "trackTitle": track.title,
            "trackArtist": track.artist,
            "currentTime": currentTime,
            "isPlaying": isPlaying
        ]
        
        if !track.album.isEmpty {
            userInfo["trackAlbum"] = track.album
        }
        
        activity.userInfo = userInfo
        activity.becomeCurrent()
        
        userActivity = activity
        
        // Update widget data
        updateWidgetData(track: track)
    }
    
    private func updateWidgetData(track: ReverieTrack?) {
        #if os(iOS)
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")
        
        if let track = track {
            sharedDefaults?.set(track.title, forKey: "currentTrackTitle")
            sharedDefaults?.set(track.artist, forKey: "currentTrackArtist")
            sharedDefaults?.set(track.albumArtData, forKey: "currentTrackAlbumArt")
            sharedDefaults?.set(isPlaying, forKey: "isPlaying")
            sharedDefaults?.set(currentTime, forKey: "currentTime")
            sharedDefaults?.set(duration, forKey: "duration")
        } else {
            sharedDefaults?.removeObject(forKey: "currentTrackTitle")
            sharedDefaults?.removeObject(forKey: "currentTrackArtist")
            sharedDefaults?.removeObject(forKey: "currentTrackAlbumArt")
            sharedDefaults?.set(false, forKey: "isPlaying")
            sharedDefaults?.set(0, forKey: "currentTime")
            sharedDefaults?.set(0, forKey: "duration")
        }
        
        // Request widget reload
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    // MARK: - Time Updates (FIXED: timer leak prevention)
    
    private func startTimeUpdates() {
        // CRITICAL FIX: Invalidate existing timer before creating new one
        timeUpdateTimer?.invalidate()
        
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                guard self.isPlaying else {
                    timer.invalidate()
                    self.timeUpdateTimer = nil
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
    
    /// Polls for end-of-track as safety net for completion handler
    private func startEndOfTrackPolling() {
        endOfTrackTimer?.invalidate()
        
        endOfTrackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                guard self.isPlaying else {
                    timer.invalidate()
                    self.endOfTrackTimer = nil
                    return
                }
                
                // Check if we're within 100ms of the end
                if self.duration > 0 && self.currentTime >= self.duration - 0.1 {
                    timer.invalidate()
                    self.endOfTrackTimer = nil
                    self.handleTrackCompletion()
                }
            }
        }
    }
    
    /// Stops all timers
    private func stopTimers() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
        
        endOfTrackTimer?.invalidate()
        endOfTrackTimer = nil
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
    
}
