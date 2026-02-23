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
#if canImport(ActivityKit)
import ActivityKit
#endif
#elseif os(macOS)
import AppKit
#endif

/// Lightweight Codable type matching QueueTrack in widget extension for JSON interop
private struct WidgetQueueTrack: Codable {
    let id: String
    let title: String
    let artist: String
}

/// Dual-mode audio playback: AVAudioEngine (local) or AVPlayer (streaming)
enum PlaybackMode: Sendable {
    case local      // AVAudioEngine – downloaded file, waveform enabled
    case streaming  // AVPlayer – network stream, no waveform
}

/// Manages audio playback with AVAudioEngine and AVPlayer, plus system integration
@MainActor
@Observable
class AudioPlayer {

    // MARK: - Public State

    var isPlaying: Bool = false
    var isStreaming: Bool = false
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
            avPlayer?.volume = volume
        }
    }

    // Playback queue (separate service)
    let playbackQueue = PlaybackQueue()

    // Signal collection for recommendations (set from outside)
    var signalCollector: SignalCollector?
    var signalModelContext: ModelContext?

    // Handoff support
    var userActivity: NSUserActivity?

    // Live Activity manager
    #if canImport(ActivityKit)
    private let liveActivityManager = LiveActivityManager.shared
    private var lastLiveActivityUpdate: TimeInterval = 0
    #endif

    // MARK: - Private – AVAudioEngine (local mode)

    private let audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var isTapInstalled = false
    private var lastWaveformUpdate: TimeInterval = 0

    // MARK: - Private – AVPlayer (streaming mode)

    private var avPlayer: AVPlayer?
    private var avPlayerItem: AVPlayerItem?
    private var playerTimeObserver: Any?
    private var playerItemObserver: NSKeyValueObservation?
    private var playerStatusObserver: NSKeyValueObservation?

    // MARK: - Private – Shared

    private var playbackMode: PlaybackMode = .local
    private var timeUpdateTimer: Timer?
    private var endOfTrackTimer: Timer?
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
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(
            audioPlayerNode,
            to: audioEngine.mainMixerNode,
            format: nil
        )
        audioEngine.prepare()
        installMeterTapIfNeeded()
    }

    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToNext() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToPrevious() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor in self?.seek(to: event.positionTime) }
                return .success
            }
            return .commandFailed
        }
    }

    // MARK: - Load Track (local file via AVAudioEngine)

    func loadTrack(_ track: ReverieTrack) async throws {
        stop()

        guard let relativePath = track.localFilePath else {
            let error = ReverieError.playback(.trackNotDownloaded(trackTitle: track.title))
            ErrorBannerState.shared.post(error)
            throw error
        }

        do {
            let fileURL = try await storageManager.getAudioFileURL(relativePath: relativePath)

            audioFile = try AVAudioFile(forReading: fileURL)

            guard let audioFile = audioFile else {
                throw ReverieError.playback(.fileLoadFailed(
                    NSError(domain: "AudioPlayer", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "AVAudioFile is nil"])
                ))
            }

            playbackMode = .local
            isStreaming = false
            currentTrack = track
            duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            currentTime = 0
            resetWaveform()
            updateNowPlayingInfo()
            startLiveActivityForCurrentTrack()

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

    // MARK: - Load Stream URL (via AVPlayer)

    func loadStream(url: URL, track: ReverieTrack) {
        stop()

        playbackMode = .streaming
        isStreaming = true
        currentTrack = track
        currentTime = 0
        duration = TimeInterval(track.durationSeconds)
        resetWaveform()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        avPlayerItem = item

        if avPlayer == nil {
            avPlayer = AVPlayer(playerItem: item)
        } else {
            avPlayer?.replaceCurrentItem(with: item)
        }
        avPlayer?.volume = volume

        // Observe status to get duration once loaded
        playerStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    let cmDuration = item.duration
                    if cmDuration.isNumeric {
                        self.duration = CMTimeGetSeconds(cmDuration)
                    }
                    self.updateNowPlayingInfo()
                }
            }
        }

        // Observe when playback finishes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackCompletion()
            }
        }

        updateNowPlayingInfo()
        startLiveActivityForCurrentTrack()
    }

    // MARK: - Unified Playback Control

    func play() {
        switch playbackMode {
        case .local:
            guard currentTrack != nil, audioFile != nil else { return }

            do {
                if !audioEngine.isRunning {
                    try audioEngine.start()
                }
                audioPlayerNode.play()
                audioPlayerNode.volume = volume
            } catch {
                let error = ReverieError.playback(.audioEngineFailed(error))
                ErrorBannerState.shared.post(error)
                return
            }

        case .streaming:
            guard avPlayer != nil else { return }
            avPlayer?.play()
        }

        isPlaying = true
        updateNowPlayingInfo()
        updateLiveActivity()
        HapticManager.shared.playPause()
        startTimeUpdates()
        startEndOfTrackPolling()
    }

    func pause() {
        switch playbackMode {
        case .local:
            audioPlayerNode.pause()
        case .streaming:
            avPlayer?.pause()
        }

        isPlaying = false
        resetWaveform()
        stopTimers()
        updateNowPlayingInfo()
        updateLiveActivity()
        HapticManager.shared.playPause()
    }

    func stop() {
        switch playbackMode {
        case .local:
            audioPlayerNode.stop()
            if let audioFile = audioFile {
                audioPlayerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.handleTrackCompletion()
                    }
                }
            }

        case .streaming:
            avPlayer?.pause()
            teardownStreamObservers()
            avPlayerItem = nil
        }

        isPlaying = false
        isStreaming = false
        currentTime = 0
        resetWaveform()
        stopTimers()

        #if canImport(ActivityKit)
        liveActivityManager.endActivity()
        #endif
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        switch playbackMode {
        case .local:
            guard let audioFile = audioFile else { return }
            let sampleRate = audioFile.fileFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)

            audioPlayerNode.stop()
            audioPlayerNode.scheduleSegment(
                audioFile,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(audioFile.length - startFrame),
                at: nil
            )
            if isPlaying {
                audioPlayerNode.play()
            }

        case .streaming:
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            avPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
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
        // Record signal: if user skipped early it's a skip, otherwise partial play
        if let track = currentTrack, let collector = signalCollector, let ctx = signalModelContext {
            if currentTime < 30 {
                collector.recordSkip(track: track, afterSeconds: currentTime, modelContext: ctx)
            } else {
                collector.recordPlay(track: track, duration: currentTime, wasFullPlay: false, modelContext: ctx)
            }
        }

        guard let nextTrack = playbackQueue.next() else {
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
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard let previousTrack = playbackQueue.previous() else {
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
        // Record full-play signal
        if let track = currentTrack, let collector = signalCollector, let ctx = signalModelContext {
            collector.recordPlay(track: track, duration: currentTime, wasFullPlay: true, modelContext: ctx)
        }
        skipToNext()
    }

    // MARK: - Streaming Helpers

    /// Transitions from streaming to local playback when download finishes
    func transitionToLocalPlayback(track: ReverieTrack) async {
        guard currentTrack?.id == track.id,
              playbackMode == .streaming,
              track.downloadState == .downloaded else {
            return
        }

        let savedTime = currentTime
        let wasPlaying = isPlaying

        do {
            try await loadTrack(track)
            seek(to: savedTime)
            if wasPlaying {
                play()
            }
        } catch {
            // Stay on stream if local load fails
        }
    }

    private func teardownStreamObservers() {
        if let observer = playerTimeObserver {
            avPlayer?.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: avPlayerItem
        )
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
        updateUserActivity()

        // Throttled Live Activity update (~every 5 seconds)
        #if canImport(ActivityKit)
        let now = Date().timeIntervalSinceReferenceDate
        if now - lastLiveActivityUpdate >= 5 {
            lastLiveActivityUpdate = now
            updateLiveActivity()
        }
        #endif
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

            // Write Up Next queue for large widget (JSON matches QueueTrack in widget)
            let upNext = playbackQueue.upcomingTracks.prefix(4).map { t in
                WidgetQueueTrack(id: t.id.uuidString, title: t.title, artist: t.artist)
            }
            if let queueData = try? JSONEncoder().encode(upNext) {
                sharedDefaults?.set(queueData, forKey: "upNextQueue")
            }
        } else {
            sharedDefaults?.removeObject(forKey: "currentTrackTitle")
            sharedDefaults?.removeObject(forKey: "currentTrackArtist")
            sharedDefaults?.removeObject(forKey: "currentTrackAlbumArt")
            sharedDefaults?.set(false, forKey: "isPlaying")
            sharedDefaults?.set(0, forKey: "currentTime")
            sharedDefaults?.set(0, forKey: "duration")
            sharedDefaults?.removeObject(forKey: "upNextQueue")
        }

        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Live Activity

    private func updateLiveActivity() {
        #if canImport(ActivityKit)
        lastLiveActivityUpdate = Date().timeIntervalSinceReferenceDate

        guard currentTrack != nil else {
            liveActivityManager.endActivity()
            return
        }

        let progress = duration > 0 ? currentTime / duration : 0
        liveActivityManager.updateActivity(
            isPlaying: isPlaying,
            progress: progress,
            elapsed: Int(currentTime),
            total: Int(duration)
        )
        #endif
    }

    func startLiveActivityForCurrentTrack() {
        #if canImport(ActivityKit)
        guard let track = currentTrack else { return }
        liveActivityManager.startActivity(
            trackTitle: track.title,
            artistName: track.artist,
            albumArtData: track.albumArtData,
            totalSeconds: Int(duration)
        )
        #endif
    }

    // MARK: - Widget Action Handling

    /// Process pending actions written by widget App Intents.
    /// Call this from the app when it becomes active (e.g. in scenePhase change).
    func processPendingWidgetAction() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")
        guard let action = sharedDefaults?.string(forKey: "pendingAction") else { return }
        sharedDefaults?.removeObject(forKey: "pendingAction")

        switch action {
        case "togglePlayPause":
            togglePlayPause()
        case "skipForward":
            skipToNext()
        case "skipBackward":
            skipToPrevious()
        default:
            break
        }
    }

    // MARK: - Time Updates

    private func startTimeUpdates() {
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

                switch self.playbackMode {
                case .local:
                    if let nodeTime = self.audioPlayerNode.lastRenderTime,
                       let playerTime = self.audioPlayerNode.playerTime(forNodeTime: nodeTime) {
                        self.currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
                    }
                case .streaming:
                    if let player = self.avPlayer {
                        let time = CMTimeGetSeconds(player.currentTime())
                        if time.isFinite {
                            self.currentTime = time
                        }
                    }
                }

                self.updateNowPlayingInfo()
            }
        }
    }

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

                if self.duration > 0 && self.currentTime >= self.duration - 0.1 {
                    timer.invalidate()
                    self.endOfTrackTimer = nil
                    self.handleTrackCompletion()
                }
            }
        }
    }

    private func stopTimers() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
        endOfTrackTimer?.invalidate()
        endOfTrackTimer = nil
    }

    // MARK: - Waveform Metering (local mode only)

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
                if self.isPlaying && self.playbackMode == .local {
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
